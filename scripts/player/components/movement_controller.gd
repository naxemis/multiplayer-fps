# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Translates input + the current [enum StateMachine.MovementStates] into a physics velocity for [Player].
## Owns the jump APIs and the velocity-timeout flag.
##
## Each physics tick this controller updates the velocity-timeout flag, reads movement input, smooths it through movement inertia, applies gravity and lerps the scalar [member movement_speed].
## [Player] then reads the per-state speed accumulators (via the [code]_walk[/code], [code]_run[/code], [code]_slide[/code], [code]_crouch_or_other[/code] callables) and the resulting velocity through [method compute_movement_velocity].
class_name MovementController
extends Component

# Signals

# Enums and constants

# @export vars
@export_category("Velocity Timeout")
## Seconds the player can press into a wall before [member velocity_timeout] flips to true and forces an idle transition.
## Refilled instantly when the player is no longer wall-stuck.
@export var max_timeout_duration: float = 0.5

@export_category("Crouching and Walking")
## Base crouch speed in m/s.
## Added to [member walk_speed] + [member run_speed] to form the grounded floor speed used everywhere.
@export var crouch_speed: float = 2.0
## Base walk speed in m/s.
## Added to [member crouch_speed] + [member run_speed] to form the grounded floor speed.
@export var walk_speed: float = 2.0

@export_category("Running")
## Upper clamp for the run-only speed accumulator in m/s.
## Run never adds more than this on top of [member walk_speed].
@export var max_run_speed: float = 2.5
## Run-speed buildup rate per second while running.
@export var run_speed_increase: float = 1.0
## Run-speed bleed-off rate per second while only walking.
@export var run_walk_decrease: float = 2.5
## Run-speed bleed-off rate per second while crouching or in air.
@export var run_crouch_decrease: float = 4.0

@export_category("Sliding")
## Upper clamp for the slide-only speed accumulator in m/s.
## The slide branch lets the value dip below zero (uphill braking) but never above this.
@export var max_slide_speed: float = 2.5

## Fraction of grounded floor speed converted into slide buildup per second on flat ground (before slope modulation).
@export var slide_buff_multiplier: float = 0.15
## Multiplier applied to the slope dot product when going uphill — reduces the slide buildup proportionally to the steepness.
@export var slope_uphill_brake_factor: float = 0.85
## Multiplier applied to the slope dot product when going downhill — adds extra slide buildup proportionally to the steepness.
@export var slope_downhill_boost_factor: float = 0.5

## Slide-speed bleed multiplier while running (fraction per second relative to the current floor speed).
## Low value means run sustains slide longest.
@export var slide_speed_run_decrease: float = 0.05
## Slide-speed bleed multiplier while walking.
@export var slide_speed_walk_decrease: float = 2.5
## Slide-speed bleed multiplier while crouching / not running.
@export var slide_speed_crouch_decrease: float = 4.0

@export_category("Speed Inertia")
## Lerp rate (per second) used to smooth changes in the final scalar [member movement_speed].
## Higher = snappier.
@export var speed_inertia: float = 7.5

@export_category("Movement Inertia")
## Lerp rate (per second) applied to planar input while grounded — controls how quickly direction changes register on the floor.
@export var on_ground_inertia: float = 8.0
## Lerp rate (per second) applied to planar input while airborne.
## Typically lower than [member on_ground_inertia] to give air control a draggy feel.
@export var in_air_inertia: float = 4.0

@export_category("Gravity")
## Gravity acceleration in m/s².
## Applied only while not on the floor.
@export var gravity_force: float = 18.0

@export_category("Jumping")
## Vertical velocity in m/s set when a fresh ground jump fires.
@export var jump_velocity: float = 7.5

@export_category("Double Jumping")
## Fraction of [member jump_velocity] applied to the second airborne jump.
## Range 0.0-1.0 in practice.
@export var double_jump_multiplier: float = 0.7
## Whether the double jump remains available after spending a wall jump.
## Currently informational; gameplay logic is in [StateMachine].
@export var can_double_jump_after_wall_jump: bool = false

@export_category("Wall Jumping")
## Multiplier applied to [member movement_speed] to derive the wall-jump vertical impulse before clamping.
@export var vertical_jump_multiplier: float = 0.85
## Lower clamp (m/s) of the wall-jump vertical impulse so the player always gets at least a usable hop.
@export var min_vertical_jump: float = 5.0
## Upper clamp (m/s) of the wall-jump vertical impulse so very high speed does not launch the player out of the level.
@export var max_vertical_jump: float = 7.5

# Public vars
## True while the player has been blocked against a wall for longer than [member max_timeout_duration].
## Forces walk/run/idle entry guards in [StateMachine] to release so the player can recover.
var velocity_timeout: bool = false # true - player is walking into wall for too long time
## Smoothed scalar movement speed (m/s) consumed by [method compute_movement_velocity] and read by [CameraController] for FOV.
var movement_speed: float = 0.0
## Run-only contribution to the floor speed.
## Builds up while running and bleeds off in other states.
var run_speed: float = 0.0
## Slide-only contribution; positive while sliding, can dip negative on uphill braking.
var slide_speed: float = 0.0

# Private vars (_)
var _player_context_module: PlayerContextModule
var _player: Player
var _state_machine: StateMachine
var _stamina_manager: StaminaManager
var _input_handler: InputHandler
var _velocity_timeout_left: float = 0.0 # current time before timeout is set to true
var _movement_directions: Vector3
var _inertia_movement_directions: Vector3
var _current_inertia: float
var _wall_jump_directions: Vector3

# _init / _ready

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _physics_process(delta: float) -> void:
	_get_velocity_timeout(delta)
	_calculate_get_movement_directions()
	_calculate_movement_inertia(delta)
	_gravity(delta)
	_update_movement_speed(delta)

# Public methods (component APIs)
## Caches sibling components and the player root from the injected context.
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context
	_player = context.node_refs.player
	_state_machine = context.components.state_machine
	_stamina_manager = context.components.stamina_manager
	_input_handler = context.components.input_handler

## Returns the raw per-frame input direction (X/Z planar, Y carries gravity and jumps).
## Used by [StateMachine] entry guards and other components.
func get_movement_directions() -> Vector3:
	return _movement_directions

## Returns the inertia-smoothed planar input used to derive velocity.
func get_inertia_movement_directions() -> Vector3:
	return _inertia_movement_directions

## Returns the direction vector applied during an active wall jump.
func get_wall_jump_directions() -> Vector3:
	return _wall_jump_directions

func _update_movement_speed(delta: float) -> void:
	var floor_speed: float = crouch_speed + walk_speed + run_speed
	var speed_before_inertia: float = maxf(0.0, floor_speed + slide_speed)
	movement_speed = lerpf(movement_speed, speed_before_inertia, 1.0 - exp(-speed_inertia * delta))

## Performs a ground jump: clears any prior vertical velocity, applies [member jump_velocity], consumes the coyote window on [StateMachine] and drains [member StaminaManager.jump_stamina_drain] once.
func jump() -> void:
	_movement_directions.y = 0
	_movement_directions.y += jump_velocity

	_state_machine.consume_coyote()

	_stamina_manager.drain_once(_stamina_manager.jump_stamina_drain)

## Performs a double jump: zeroes negative vertical velocity (so the player reliably rises), applies [member jump_velocity] * [member double_jump_multiplier], drains [member StaminaManager.double_jump_stamina_drain] and clears any active wall-jump direction.
func double_jump() -> void:
	if get_movement_directions().y < 0:
		_movement_directions.y = 0.0

	_movement_directions.y += jump_velocity * double_jump_multiplier

	_stamina_manager.drain_once(_stamina_manager.double_jump_stamina_drain)

	_reset_wall_jumping_directions()

## Performs a wall jump if the [StateMachine] guard still passes:
## [br]- Resets the active wall-jump direction so multi-wall bounces start fresh each call.
## [br]- Picks a vertical impulse scaled from [member movement_speed] and clamped to [member min_vertical_jump] / [member max_vertical_jump].
## [br]- Picks a horizontal direction by reflecting against the wall normal; if [code]change_wall_jump_direction[/code] is held the reflection uses the negated forward axis (so the player bounces away from the wall), otherwise the player keeps roughly the original direction.
## [br]- Drains [member StaminaManager.wall_jump_stamina_drain].
##
## Also resets the wall-jump direction whenever the player is on the floor.
func wall_jump() -> void:
	if _state_machine._can_enter_wall_jump():
		_reset_wall_jumping_directions()

		# calculates and clamps vertical jump force after wall jumping
		var vertical_jump: float = movement_speed * vertical_jump_multiplier
		vertical_jump = clampf(vertical_jump, min_vertical_jump, max_vertical_jump)

		# gives player slight jump in vertical direction depending on his speed; more speed = bigger jump
		_movement_directions.y = 0.0
		_movement_directions.y += vertical_jump

		var player_transform: Transform3D = _player.transform
		# direction of wall jump
		if !_input_handler.change_wall_jump_dir_held: # player wants to jump in same direction he jumped from
			_wall_jump_directions = -_player.get_wall_normal().direction_to(-player_transform.basis.z * _movement_directions)
		else: # player wants to "bounce" from a wall
			_wall_jump_directions = -_player.get_wall_normal().direction_to(-player_transform.basis.z * -_movement_directions)

		_stamina_manager.drain_once(_stamina_manager.wall_jump_stamina_drain)

	if _player.is_on_floor():
		_reset_wall_jumping_directions()

## Returns the velocity to assign to [member CharacterBody3D.velocity] this frame.
## Combines transform-basis planar movement scaled by [member movement_speed] with the persisted vertical component.
## While in [code]WALL_JUMP[/code] the planar part is replaced by an internal reflected direction so the leap follows the wall reflection.
func compute_movement_velocity() -> Vector3:
	var transform_x: Vector3 = _player.global_transform.basis.x * _inertia_movement_directions.x
	var transform_y: Vector3 = _player.global_transform.basis.y * _movement_directions.y
	var transform_z: Vector3 = _player.global_transform.basis.z * _inertia_movement_directions.z

	if _state_machine._current_state != _state_machine.MovementStates.WALL_JUMP:
		return (transform_x + transform_z) * movement_speed + transform_y
	else:
		return _wall_jump_directions * movement_speed + transform_y

# Private methods (_)
func _is_blocked_on_wall() -> bool:
	return _player.is_on_floor() and _player.is_on_wall() and _player.velocity.z == 0 and _player.velocity.x == 0

func _get_velocity_timeout(delta) -> void:
	_velocity_timeout_left = clampf(_velocity_timeout_left, 0.0, max_timeout_duration)

	if _is_blocked_on_wall():
		_velocity_timeout_left -= delta
	else:
		_velocity_timeout_left = max_timeout_duration

	if _velocity_timeout_left <= 0:
		velocity_timeout = true
	else:
		velocity_timeout = false

func _walk() -> void:
	var delta: float = get_physics_process_delta_time()

	run_speed -= run_walk_decrease * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)

	var floor_speed: float = crouch_speed + walk_speed + run_speed
	slide_speed -= floor_speed * slide_speed_walk_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _run() -> void:
	var delta: float = get_physics_process_delta_time()

	run_speed += run_speed_increase * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)

	var floor_speed: float = crouch_speed + walk_speed + run_speed
	slide_speed -= floor_speed * slide_speed_run_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _slide() -> void:
	var delta: float = get_physics_process_delta_time()

	var calculating_slope: Vector3 = _player.get_floor_normal() * -_player.transform.basis.z
	var slope_value: float = calculating_slope.z + calculating_slope.x
	var slope_factor: float = slope_uphill_brake_factor if slope_value < 0.0 else slope_downhill_boost_factor
	var slope_interference: float = slope_value * slope_factor

	var floor_speed: float = crouch_speed + walk_speed + run_speed
	var actual_slide_buff: float = floor_speed * (slide_buff_multiplier + slope_interference)

	slide_speed += actual_slide_buff * delta
	slide_speed = clampf(slide_speed, -floor_speed, max_slide_speed)

func _crouch_or_other() -> void:
	var delta: float = get_physics_process_delta_time()

	run_speed -= run_crouch_decrease * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)

	slide_speed -= slide_speed_crouch_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _calculate_get_movement_directions() -> void:
	var axis: Vector3 = _input_handler.movement_axis
	_movement_directions.x = axis.x
	_movement_directions.z = axis.z

func _calculate_movement_inertia(delta) -> void:
	match _player.is_on_floor():
		true: _current_inertia = on_ground_inertia
		false: _current_inertia = in_air_inertia

	_inertia_movement_directions.x = lerpf(_inertia_movement_directions.x, get_movement_directions().x, _current_inertia * delta)
	_inertia_movement_directions.z = lerpf(_inertia_movement_directions.z, get_movement_directions().z, _current_inertia * delta)

func _gravity(delta) -> void:
	if !_player.is_on_floor():
		_movement_directions.y -= gravity_force * delta
	else:
		pass

func _reset_wall_jumping_directions() -> void:
	_wall_jump_directions = Vector3(1, 0, 1)
