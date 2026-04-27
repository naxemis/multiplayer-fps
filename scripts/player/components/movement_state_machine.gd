class_name MovementStateMachine
extends Node

# Signals
signal state_changed(new_state: int)

# Enums and constants
enum MovementStates {IDLE, WALK, RUN, CROUCH, SLIDE, JUMP, DOUBLE_JUMP, WALL_JUMP, FALLING}

# @export vars
@export_category("Coyote Time")
@export var default_coyote_time: float = 0.15

# Public vars

# Private vars (_)
var _current_state: int = MovementStates.IDLE
var _player: Player
var _uncrouch_ray_cast: RayCast3D
var _unslide_ray_cast: RayCast3D
var _can_double_jump: bool = true

# @onready vars
@onready var _uncrouch_ray_cast_colliding: bool
@onready var _unslide_ray_cast_colliding: bool

# _init / _ready
func _ready() -> void:
	_create_ray_casts()

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func process(delta: float) -> void:
	_calculate_coyote_time(delta)
	_player_stand_up_check()
	_reset_double_jump()
	_current_state = _update_state()

# Public methods (component APIs)
func set_references(player: Player) -> void:
	_player = player

# Private methods (_)
func _make_ray_cast(pos: Vector3, target: Vector3) -> RayCast3D:
	var ray_cast := RayCast3D.new()
	ray_cast.position = pos
	ray_cast.target_position = target
	ray_cast.enabled = true
	add_child(ray_cast)
	return ray_cast

func _create_ray_casts() -> bool:
	_uncrouch_ray_cast = _make_ray_cast(Vector3(0, 1.2, 0), Vector3(0, -0.6, 0))
	_unslide_ray_cast = _make_ray_cast(Vector3(0, 0.6, 0), Vector3(0, -0.6, 0))
	return true

func _player_stand_up_check() -> void:
	_uncrouch_ray_cast_colliding = _uncrouch_ray_cast.is_colliding()
	_unslide_ray_cast_colliding = _unslide_ray_cast.is_colliding()
	
var coyote_time_left: float = 0.0
var coyote_time_active: bool = true
func _calculate_coyote_time(delta: float) -> void:
	if _player.is_on_floor():
		coyote_time_left = default_coyote_time
	else:
		coyote_time_left -= delta
	
	coyote_time_active = coyote_time_left > 0.0

func _is_moving() -> bool:
	return _player.movement_directions.x != 0 or _player.movement_directions.z != 0

func _is_moving_forward() -> bool:
	return _player.movement_directions.z < 0

func _has_stamina_for(cost: float) -> bool:
	return _player.stamina - cost > 0 and _player.stamina > _player.stamina_safe_zone

func _minimum_stamina(minimum: float) -> bool:
	return _player.stamina > minimum

func _is_on_ground() -> bool:
	return _player.is_on_floor() and _player.velocity.y	<= 0

func _can_jump_off_ground() -> bool:
	return _is_on_ground() and coyote_time_active

func _reset_double_jump() -> void:
	if _is_on_ground():
		_can_double_jump = true

func _can_enter_idle() -> bool:
	return (!_is_moving() and _is_on_ground() and !_uncrouch_ray_cast_colliding) or _player.velocity_timeout

func _can_enter_walk() -> bool:
	return _is_moving() and _is_on_ground() and !_uncrouch_ray_cast_colliding and !_player.velocity_timeout

func _can_enter_run() -> bool:
	var input_run: bool = Input.is_action_pressed("run")

	return input_run and _is_moving_forward() and _is_on_ground() and !_uncrouch_ray_cast_colliding and !_player.velocity_timeout

func _can_enter_crouch() -> bool:
	var input_crouch: bool = Input.is_action_pressed("crouch")

	return ((input_crouch and _is_on_ground()) and !_unslide_ray_cast_colliding) or _uncrouch_ray_cast_colliding

func _can_enter_slide() -> bool:
	var input_slide: bool = Input.is_action_pressed("slide")

	return input_slide and _is_on_ground() and _is_moving_forward() and !_player.velocity_timeout and _minimum_stamina(0.0)

func _can_enter_jump() -> bool:
	var input_jump: bool = Input.is_action_just_pressed("jump")
	var no_blocked_state: bool = _current_state != MovementStates.CROUCH

	return input_jump and _can_jump_off_ground() and no_blocked_state and _has_stamina_for(_player.jump_stamina_drain)

func _can_enter_double_jump() -> bool:
	var input_jump: bool = Input.is_action_just_pressed("jump")
	var in_air: bool = !_player.is_on_floor() and !coyote_time_active
	var already_in_air_state: bool = (_current_state == MovementStates.JUMP or _current_state == MovementStates.FALLING)
	
	return input_jump and in_air and already_in_air_state and _has_stamina_for(_player.double_jump_stamina_drain) and _can_double_jump
	
func _can_enter_wall_jump() -> bool:
	return Input.is_action_just_pressed("jump") and _player.is_on_wall_only() and _is_moving() and _has_stamina_for(_player.wall_jump_stamina_drain)

func _can_enter_falling() -> bool:
	return !_player.is_on_floor() and _player.velocity.y < 0

func _is_above_stamina_safe_zone() -> bool:
	return _player.stamina > _player.stamina_safe_zone

func _compute_next_state() -> int:
	if _can_enter_jump(): return MovementStates.JUMP
	if _can_enter_wall_jump(): return MovementStates.WALL_JUMP
	if _can_enter_double_jump(): 
		_can_double_jump = false
		return MovementStates.DOUBLE_JUMP
	
	if _can_enter_slide():
		if _current_state == MovementStates.SLIDE or _is_above_stamina_safe_zone():
			return MovementStates.SLIDE
		return _current_state
	
	if _can_enter_run(): return MovementStates.RUN
	if _can_enter_crouch(): return MovementStates.CROUCH
	if _can_enter_walk(): return MovementStates.WALK
	if _can_enter_idle(): return MovementStates.IDLE
	if _can_enter_falling(): return MovementStates.FALLING
	
	return _current_state

func _update_state() -> int:
	var new_state := _compute_next_state()
	
	if new_state != _current_state:
		_current_state = new_state
		state_changed.emit(new_state)
		
	return _current_state