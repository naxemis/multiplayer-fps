# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Translates input + the current [enum StateMachine.MovementStates] into a physics velocity for [Player].
## Owns the jump APIs and the velocity-timeout flag.
##
## Each physics tick this controller updates the velocity-timeout flag, reads movement input, smooths it through movement inertia, applies gravity and lerps the scalar [member movement_speed] toward the per-state target returned by [method _target_speed_for_state].
## [Player] reads the resulting velocity through [method compute_movement_velocity].
class_name MovementController
extends Component

# Signals

# Enums and constants

# @export vars
@export_category("Velocity Timeout")
## Seconds the player can press into a wall before [member velocity_timeout] flips to true and forces an idle transition.
## Refilled instantly when the player is no longer wall-stuck.
@export var max_timeout_duration: float = 0.5

@export_category("Movement Speed")
## Target [member movement_speed] in m/s while in [code]IDLE[/code].
@export var idle_speed: float = 0.0
## Target [member movement_speed] in m/s while in [code]CROUCH[/code].
@export var crouch_speed: float = 2.0
## Target [member movement_speed] in m/s while in [code]WALK[/code].
@export var walk_speed: float = 4.0
## Target [member movement_speed] in m/s while in [code]RUN[/code].
@export var run_speed: float = 6.0
## Target [member movement_speed] in m/s while in [code]SLIDE[/code].
@export var slide_speed: float = 8.0
## Maximum speed a single slide can add on top of the speed the player entered the slide with.
## Effective slide target is clamped to [code]entry_speed + max_slide_speed_gain[/code], so chaining slides is needed to reach [member slide_speed] from a walking start.
@export var max_slide_speed_gain: float = 2.0

@export_category("Speed Inertia")
## Default lerp rate (per second) used while ramping [member movement_speed] up toward the target in [code]IDLE[/code], [code]CROUCH[/code] and [code]WALK[/code].
@export var normal_speed_acceleration: float = 8.0
## Lerp rate used while ramping up to [member run_speed] — lower value means run takes longer to reach top speed.
@export var run_speed_acceleration: float = 2.0
## Lerp rate used while ramping up to [member slide_speed] — high value snaps the player into slide momentum.
@export var slide_speed_acceleration: float = 10.0
## Lerp rate used while bleeding excess speed in [code]IDLE[/code].
@export var idle_speed_deacceleration: float = 6.0
## Lerp rate used while bleeding excess speed in [code]CROUCH[/code].
@export var crouch_speed_deacceleration: float = 4.0
## Lerp rate used while bleeding excess speed in [code]WALK[/code].
@export var walk_speed_deacceleration: float = 2.0
## Lerp rate used while bleeding excess speed in [code]RUN[/code].
## Low value lets slide momentum carry into a run.
@export var run_speed_deacceleration: float = 0.5
## Lerp rate used while bleeding excess speed in [code]SLIDE[/code].
@export var slide_speed_deacceleration: float = 0.5

@export_category("Movement Inertia")
## Lerp rate (per second) applied to planar input while grounded — controls how quickly direction changes register on the floor.
@export var on_ground_inertia: float = 8.0
## Lerp rate (per second) applied to planar input while airborne.
## Typically lower than [member on_ground_inertia] to give air control a draggy feel.
@export var in_air_inertia: float = 4.0

@export_category("Gravity")
## Gravity accelerationeration in m/s².
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
var _slide_entry_speed: float = 0.0

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
## Also connects to [signal StateMachine.state_changed] to fire jump impulses.
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context
	_player = context.node_refs.player
	_state_machine = context.components.state_machine
	_stamina_manager = context.components.stamina_manager
	_input_handler = context.components.input_handler

	_state_machine.state_changed.connect(_on_state_changed)

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
func _on_state_changed(new_state: int) -> void:
	var states := _state_machine.MovementStates

	match new_state:
		states.SLIDE: _slide_entry_speed = movement_speed
		states.JUMP: jump()
		states.DOUBLE_JUMP: double_jump()
		states.WALL_JUMP: wall_jump()

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

func _has_movement_input() -> bool:
	return _movement_directions.x != 0.0 or _movement_directions.z != 0.0

func _target_speed_for_state(state: int) -> float:
	var states := _state_machine.MovementStates
	match state:
		states.IDLE: return idle_speed
		states.CROUCH: return crouch_speed if _has_movement_input() else idle_speed
		states.WALK: return walk_speed
		states.RUN: return run_speed
		states.SLIDE: return minf(slide_speed, _slide_entry_speed + max_slide_speed_gain)
	return movement_speed

func _acceleration_speed_for_state(state: int) -> float:
	var states := _state_machine.MovementStates
	match state:
		states.RUN: return run_speed_acceleration
		states.SLIDE: return slide_speed_acceleration
	return normal_speed_acceleration

func _deacceleration_speed_for_state(state: int) -> float:
	var states := _state_machine.MovementStates
	match state:
		states.IDLE: return idle_speed_deacceleration
		states.CROUCH: return crouch_speed_deacceleration
		states.WALK: return walk_speed_deacceleration
		states.RUN: return run_speed_deacceleration
		states.SLIDE: return slide_speed_deacceleration
	return normal_speed_acceleration

func _update_movement_speed(delta: float) -> void:
	var state: int = _state_machine._current_state
	var states := _state_machine.MovementStates

	# Airborne states freeze movement_speed so jumps carry their pre-jump momentum.
	if state == states.JUMP or state == states.DOUBLE_JUMP or state == states.WALL_JUMP or state == states.FALL:
		return

	var target: float = _target_speed_for_state(state)
	var rate: float = _acceleration_speed_for_state(state) if target >= movement_speed else _deacceleration_speed_for_state(state)
	movement_speed = lerpf(movement_speed, target, 1.0 - exp(-rate * delta))

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
