# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

class_name MovementController
extends Node

# Signals

# Enums and constants

# @export vars
@export_category("Velocity Timeout")
@export var max_timeout_duration: float = 0.5

@export_category("Crouching and Walking")
@export var crouch_speed: float = 2.0
@export var walk_speed: float = 2.0

@export_category("Running")
@export var max_run_speed: float = 2.5
@export var run_speed_increase: float = 1.0
@export var run_walk_decrease: float = 2.5
@export var run_crouch_decrease: float = 4.0

@export_category("Sliding")
@export var max_slide_speed: float = 2.5

@export var slide_buff_multiplier: float = 0.15
@export var slope_uphill_brake_factor: float = 0.85
@export var slope_downhill_boost_factor: float = 0.5

@export var slide_speed_run_decrease: float = 0.05
@export var slide_speed_walk_decrease: float = 2.5
@export var slide_speed_crouch_decrease: float = 4.0

@export_category("Speed Inertia")
@export var speed_inertia: float = 7.5

@export_category("Movement Inertia")
@export var on_ground_inertia: float = 8.0
@export var in_air_inertia: float = 4.0

@export_category("Gravity")
@export var gravity_force: float = 18.0

@export_category("Jumping")
@export var jump_velocity: float = 7.5

@export_category("Double Jumping")
@export var double_jump_multiplier: float = 0.7
@export var can_double_jump_after_wall_jump: bool = false

@export_category("Wall Jumping")
@export var vertical_jump_multiplier: float = 0.85
@export var min_vertical_jump: float = 5.0
@export var max_vertical_jump: float = 7.5

# Public vars
var velocity_timeout: bool = false # true - player is walking into wall for too long time
var movement_speed: float = 0.0
var run_speed: float = 0.0
var slide_speed: float = 0.0

# Private vars (_)
var _player_context_module: PlayerContextModule
var _player: Player
var _state_machine: StateMachine
var _stamina_manager: StaminaManager
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
func pass_player_context_module(player_context: PlayerContextModule) -> void:
	_player_context_module = player_context
	_player = player_context.node_refs.player
	_state_machine = player_context.components.state_machine
	_stamina_manager = player_context.components.stamina_manager

func get_movement_directions() -> Vector3:
	return _movement_directions

func get_inertia_movement_directions() -> Vector3:
	return _inertia_movement_directions

func get_wall_jump_directions() -> Vector3:
	return _wall_jump_directions

func _update_movement_speed(delta: float) -> void:
	var floor_speed: float = crouch_speed + walk_speed + run_speed
	var speed_before_inertia: float = maxf(0.0, floor_speed + slide_speed)
	movement_speed = lerpf(movement_speed, speed_before_inertia, 1.0 - exp(-speed_inertia * delta))

func jump() -> void:
	_movement_directions.y = 0
	_movement_directions.y += jump_velocity

	_state_machine.consume_coyote()

	_stamina_manager.one_time_stamina_drain(_stamina_manager.jump_stamina_drain)

func double_jump() -> void:
	if get_movement_directions().y < 0:
		_movement_directions.y = 0.0

	_movement_directions.y += jump_velocity * double_jump_multiplier

	_stamina_manager.one_time_stamina_drain(_stamina_manager.double_jump_stamina_drain)

	_reset_wall_jumping_directions()

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
		if !Input.is_action_pressed("change_wall_jump_direction"): # player wants to jump in same direction he jumped from
			_wall_jump_directions = -_player.get_wall_normal().direction_to(-player_transform.basis.z * _movement_directions)
		else: # player wants to "bounce" from a wall
			_wall_jump_directions = -_player.get_wall_normal().direction_to(-player_transform.basis.z * -_movement_directions)

		_stamina_manager.one_time_stamina_drain(_stamina_manager.wall_jump_stamina_drain)

	if _player.is_on_floor():
		_reset_wall_jumping_directions()

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
	_movement_directions.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	_movement_directions.z = Input.get_action_strength("back") - Input.get_action_strength("forward")

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
