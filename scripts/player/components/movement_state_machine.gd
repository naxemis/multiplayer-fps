class_name MovementStateMachine
extends Node

# Signals
signal state_changed(new_state: int)

# Enums and constants
enum MovementStates {IDLE, WALK, RUN, CROUCH, SLIDE, JUMP, DOUBLE_JUMP, WALL_JUMP, FALL}

# @export vars
@export_category("Coyote Time")
@export var default_coyote_time: float = 0.15

# Public vars

# Private vars (_)
var _current_state: int = MovementStates.IDLE
var _uncrouch_ray_cast: RayCast3D
var _unslide_ray_cast: RayCast3D
var _can_double_jump: bool = true
var _coyote_time_left: float = 0.0
var _coyote_time_active: bool = true
var _player_context_module: PlayerContextModule

# @onready vars

# _init / _ready
func _ready() -> void:
	_create_ray_casts()

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func physics_process(delta: float) -> void:
	_calculate_coyote_time(delta)
	_reset_double_jump()
	_current_state = _update_state()

# Public methods
func pass_player_context_module(player_context: PlayerContextModule) -> void:
	_player_context_module = player_context

func consume_coyote() -> void:
	_coyote_time_left = 0

# Private methods (_)
func _make_ray_cast(pos: Vector3, target: Vector3) -> RayCast3D:
	var ray_cast := RayCast3D.new()
	ray_cast.position = pos
	ray_cast.target_position = target
	ray_cast.enabled = true
	add_child(ray_cast)
	return ray_cast

func _create_ray_casts() -> bool:
	_uncrouch_ray_cast = _make_ray_cast(Vector3(0, 1.2, 0), Vector3(0, 0.6, 0))
	_unslide_ray_cast = _make_ray_cast(Vector3(0, 0.6, 0), Vector3(0, 0.6, 0))
	return true

func _is_moving() -> bool:
	return _player_context_module.physics_data.movement_directions.x != 0 or _player_context_module.physics_data.movement_directions.z != 0

func _is_moving_forward() -> bool:
	return _player_context_module.physics_data.movement_directions.z < 0

func _has_stamina_for(cost: float) -> bool:
	return _player_context_module.physics_data.stamina - cost > 0 and _player_context_module.physics_data.stamina > _player_context_module.init_data.stamina_safe_zone

func _minimum_stamina(minimum: float) -> bool:
	return _player_context_module.physics_data.stamina > minimum

func _is_on_ground() -> bool:
	return _player_context_module.physics_data.is_on_floor and _player_context_module.physics_data.velocity.y <= 0

func _is_airborne_state(state: int) -> bool:
	return state == MovementStates.JUMP \
		or state == MovementStates.DOUBLE_JUMP \
		or state == MovementStates.WALL_JUMP \
		or state == MovementStates.FALL

func _calculate_coyote_time(delta: float) -> void:
	if _is_on_ground():
		_coyote_time_left = default_coyote_time
	else:
		_coyote_time_left -= delta
	
	_coyote_time_active = _coyote_time_left > 0.0

func _can_jump_off_ground() -> bool:
	return _is_on_ground() and _coyote_time_active

func _reset_double_jump() -> void:
	if _is_on_ground():
		_can_double_jump = true

func _can_enter_idle() -> bool:
	return (!_is_moving() and _is_on_ground() and !_uncrouch_ray_cast.is_colliding()) or _player_context_module.components.movement_controller.velocity_timeout

func _can_enter_walk() -> bool:
	return _is_moving() and _is_on_ground() and !_uncrouch_ray_cast.is_colliding() and !_player_context_module.components.movement_controller.velocity_timeout

func _can_enter_run() -> bool:
	var input_run: bool = Input.is_action_pressed("run")

	return input_run and _is_moving_forward() and _is_on_ground() and !_uncrouch_ray_cast.is_colliding() and !_player_context_module.components.movement_controller.velocity_timeout

func _can_enter_crouch() -> bool:
	var input_crouch: bool = Input.is_action_pressed("crouch")
	var stuck_under_ceiling: bool = _uncrouch_ray_cast.is_colliding() or _unslide_ray_cast.is_colliding()

	return (input_crouch or stuck_under_ceiling) and _is_on_ground()

func _can_enter_slide() -> bool:
	var input_slide: bool = Input.is_action_pressed("slide")

	return input_slide and _is_on_ground() and _is_moving_forward() and !_player_context_module.components.movement_controller.velocity_timeout and _minimum_stamina(0.0) and !_unslide_ray_cast.is_colliding()

func _can_enter_jump() -> bool:
	var input_jump: bool = Input.is_action_just_pressed("jump")
	var no_blocked_state: bool = _current_state != MovementStates.CROUCH

	return input_jump and _can_jump_off_ground() and no_blocked_state and _has_stamina_for(_player_context_module.init_data.jump_stamina_drain)

func _can_enter_double_jump() -> bool:
	var input_jump: bool = Input.is_action_just_pressed("jump")
	var in_air: bool = !_is_on_ground() and !_coyote_time_active
	
	return input_jump and in_air and _has_stamina_for(_player_context_module.init_data.double_jump_stamina_drain) and _can_double_jump
	
func _can_enter_wall_jump() -> bool:
	return Input.is_action_just_pressed("jump") and _player_context_module.physics_data.is_on_wall_only and _is_moving() and _has_stamina_for(_player_context_module.init_data.wall_jump_stamina_drain)

func _can_enter_fall() -> bool:
	var can_fall_from_current_state: bool = _current_state != MovementStates.WALL_JUMP

	return _is_airborne_state(_current_state) and !_player_context_module.physics_data.is_on_wall_only and _player_context_module.physics_data.velocity.y < 0 and can_fall_from_current_state

func _is_above_stamina_safe_zone() -> bool:
	return _player_context_module.physics_data.stamina > _player_context_module.init_data.stamina_safe_zone

func _compute_next_state() -> int:
	if _can_enter_jump(): return MovementStates.JUMP
	if _can_enter_wall_jump(): return MovementStates.WALL_JUMP
	if _can_enter_double_jump(): 
		_can_double_jump = false
		return MovementStates.DOUBLE_JUMP
	
	if _can_enter_fall(): return MovementStates.FALL
	
	if _can_enter_slide():
		if _current_state == MovementStates.SLIDE or _is_above_stamina_safe_zone():
			return MovementStates.SLIDE
		return _current_state
	
	if _can_enter_run(): return MovementStates.RUN
	if _can_enter_crouch(): return MovementStates.CROUCH
	if _can_enter_walk(): return MovementStates.WALK
	if _can_enter_idle(): return MovementStates.IDLE
	
	return _current_state

func _update_state() -> int:
	var new_state := _compute_next_state()
	
	if new_state != _current_state:
		_current_state = new_state
		state_changed.emit(new_state)
	elif _can_enter_wall_jump(): # player can wall jump multiple times, even if they are already in wall jump state
		state_changed.emit(new_state)
		
	return _current_state
