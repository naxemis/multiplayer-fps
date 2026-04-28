class_name CameraController
extends Node

signal freelook_started
signal freelook_stopped

@export_category("Mouse Movement")
@export var mouse_sensitivity: float = 0.075:
	set(value):
		mouse_sensitivity = value
		_mouse_sensitivity_rad = deg_to_rad(value)

@export var head_rotation_limit: float = 90:
	set(value):
		head_rotation_limit = value
		_head_rotation_limit_rad = deg_to_rad(value)

@export_category("Camera Freelook")
@export var free_look_rotation_limit: Vector2 = Vector2(35.0, 50):
	set(value):
		free_look_rotation_limit = value
		_free_look_rotation_limit_rad = Vector2(deg_to_rad(value.x), deg_to_rad(value.y))

@export var free_look_sensitivity_multiplier: float = 3.0
@export var free_look_return_speed: float = 12.5

@export_category("Camera FOV")
@export var default_camera_fov: float = 59.0
@export var fov_speed_buff_factor: float = 2.5
@export var fov_interpolation_speed: float = 2.5

var _mouse_sensitivity_rad: float = deg_to_rad(0.075)
var _head_rotation_limit_rad: float = deg_to_rad(head_rotation_limit)
var _free_look_rotation_limit_rad: Vector2 = Vector2(deg_to_rad(free_look_rotation_limit.x), deg_to_rad(free_look_rotation_limit.y))
var _base_head_rotation: Vector2
var _free_look_rotation: Vector2
var _head_rotation: Vector2
var _camera_fov: float
var _context: PlayerContext

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_look"):
		emit_signal("freelook_started")
	elif event.is_action_released("free_look"):
		emit_signal("freelook_stopped")

	_body_rotation(event)
	_calculate_base_head_rotation(event)
	_calculate_free_look_rotation(event)

func process(delta: float, context: PlayerContext) -> void:
	_context = context

	_free_look_return(delta)
	_calculate_head_rotation(_base_head_rotation, _free_look_rotation)
	_calculate_camera_fov(delta, _context.movement_speed)

func get_head_rotation() -> Vector2:
	return _head_rotation

func _body_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		_context.body_rotation.y -= event.relative.x * _mouse_sensitivity_rad

		const ROTATION_MIN: float = 0.0
		const ROTATION_MAX: float = TAU
		
		_context.body_rotation.y = wrapf(_context.body_rotation.y, ROTATION_MIN, ROTATION_MAX)

func _calculate_base_head_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		_base_head_rotation.x -= event.relative.y * _mouse_sensitivity_rad
		_base_head_rotation.x = clampf(_base_head_rotation.x, -_head_rotation_limit_rad, _head_rotation_limit_rad)

func _calculate_free_look_rotation(event) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("free_look"):
		_free_look_rotation.x -= event.relative.y * (_mouse_sensitivity_rad * free_look_sensitivity_multiplier)
		_free_look_rotation.y -= event.relative.x * (_mouse_sensitivity_rad * free_look_sensitivity_multiplier)

		_free_look_rotation.x = clampf(_free_look_rotation.x, -_free_look_rotation_limit_rad.x, _free_look_rotation_limit_rad.x)
		_free_look_rotation.y = clampf(_free_look_rotation.y, -_free_look_rotation_limit_rad.y, _free_look_rotation_limit_rad.y)

func _free_look_return(delta) -> void:
	if !Input.is_action_pressed("free_look"):
		_free_look_rotation.x = lerpf(_free_look_rotation.x, 0.0, free_look_return_speed * delta)
		_free_look_rotation.y = lerpf(_free_look_rotation.y, 0.0, free_look_return_speed * delta)

func _calculate_head_rotation(base, free_look) -> void:
	_head_rotation = base + free_look
	
	_head_rotation.x = clampf(_head_rotation.x, -_head_rotation_limit_rad, _head_rotation_limit_rad)
	
	_context.head.rotation = Vector3(_head_rotation.x, _head_rotation.y, 0.0)

func _calculate_camera_fov(delta: float, movement_speed: float) -> void:
	var base_camera_fov: float = default_camera_fov - (_context.walk_speed + _context.crouch_speed)
	var fov_speed_buff: float = movement_speed * fov_speed_buff_factor
	
	_camera_fov = base_camera_fov + fov_speed_buff
	
	_context.camera.fov = lerpf(_context.camera.fov, _camera_fov, fov_interpolation_speed * delta)
