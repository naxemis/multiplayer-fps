# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Translates mouse motion into player body yaw, head pitch and free-look offsets, and drives the [Camera3D] FOV based on current movement speed.
##
## Mouse motion arrives through [signal InputHandler.mouse_motion]; the controller connects to it in [method pass_context_module] and dispatches to body / head / free-look math based on [member InputHandler.freelook_held].
## Per-frame work happens in [method _process]: free-look return-to-center, combined head rotation and FOV interpolation.
## Designers tune sensitivity and limits via exported degree-valued fields; the controller caches a radians copy of each for the per-frame math.
class_name CameraController
extends Component

# Signals

# Enums and constants

# @onready vars
@export_category("Mouse Movement")
## Look sensitivity in degrees of rotation per pixel of mouse motion.
## Applied to both body yaw and head pitch (and scaled further during free-look).
## The setter recomputes the cached radians copy used by per-frame math.
@export var mouse_sensitivity: float = 0.075:
	set(value):
		mouse_sensitivity = value
		_mouse_sensitivity_rad = deg_to_rad(value)

## Maximum absolute head pitch in degrees (applies symmetrically up/down).
## Typical range 60-90.
## The setter recomputes the cached radians copy used by per-frame math.
@export var head_rotation_limit: float = 90:
	set(value):
		head_rotation_limit = value
		_head_rotation_limit_rad = deg_to_rad(value)

@export_category("Camera Freelook")
## Maximum free-look offset in degrees as [code]Vector2(pitch, yaw)[/code] relative to the body.
## Clamps how far the camera can swivel without turning the body.
## The setter recomputes the cached radians copy used by per-frame math.
@export var free_look_rotation_limit: Vector2 = Vector2(35.0, 50):
	set(value):
		free_look_rotation_limit = value
		_free_look_rotation_limit_rad = Vector2(deg_to_rad(value.x), deg_to_rad(value.y))

## Multiplier applied to [member mouse_sensitivity] while free-look is held, letting the player whip the view around faster than normal aiming.
@export var free_look_sensitivity_multiplier: float = 3.0
## Lerp rate (per second) at which free-look offsets snap back to zero once the [code]free_look[/code] action is released.
## Higher = snappier return.
@export var free_look_return_speed: float = 12.5

@export_category("Camera FOV")
## Base camera field of view in degrees applied when the player is standing still.
@export var default_camera_fov: float = 59.0
## Multiplier applied to [member MovementController.movement_speed] when computing the FOV boost.
## Larger values widen the FOV more aggressively while running/sliding.
@export var fov_speed_buff_factor: float = 2.5
## Lerp rate (per second) used to smooth the camera's actual FOV toward the target computed each frame.
@export var fov_interpolation_speed: float = 2.5

# Public vars

# Private vars (_)
var _mouse_sensitivity_rad: float = deg_to_rad(0.075)
var _head_rotation_limit_rad: float = deg_to_rad(head_rotation_limit)
var _free_look_rotation_limit_rad: Vector2 = Vector2(deg_to_rad(free_look_rotation_limit.x), deg_to_rad(free_look_rotation_limit.y))
var _base_head_rotation: Vector2
var _free_look_rotation: Vector2
var _head_rotation: Vector2
var _camera_fov: float
var _player_context_module: PlayerContextModule
var _player: Player
var _head: Node3D
var _camera: Camera3D
var _movement_controller: MovementController
var _input_handler: InputHandler

# _init / _ready

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _process(delta: float) -> void:
	_free_look_return(delta)
	_calculate_head_rotation(_base_head_rotation, _free_look_rotation)
	_calculate_camera_fov(delta, _movement_controller.movement_speed)

# Public methods (component APIs)
## Caches the player, head pivot, camera, [MovementController] and [InputHandler] off the injected [PlayerContextModule] and connects to [signal InputHandler.mouse_motion].
## See [method Component.pass_context_module].
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context
	_player = context.node_refs.player
	_head = context.node_refs.head
	_camera = context.node_refs.camera
	_movement_controller = context.components.movement_controller
	_input_handler = context.components.input_handler

	_input_handler.mouse_motion.connect(_on_mouse_motion)

## Returns the current combined head pitch/yaw in radians applied this frame.
func get_head_rotation() -> Vector2:
	return _head_rotation

# Private methods (_)
func _on_mouse_motion(relative: Vector2) -> void:
	if _input_handler.freelook_held:
		_calculate_free_look_rotation(relative)
	else:
		_body_rotation(relative)
		_calculate_base_head_rotation(relative)

func _body_rotation(relative: Vector2) -> void:
	_player.rotation.y -= relative.x * _mouse_sensitivity_rad

	const ROTATION_MIN: float = 0.0
	const ROTATION_MAX: float = TAU

	_player.rotation.y = wrapf(_player.rotation.y, ROTATION_MIN, ROTATION_MAX)

func _calculate_base_head_rotation(relative: Vector2) -> void:
	_base_head_rotation.x -= relative.y * _mouse_sensitivity_rad
	_base_head_rotation.x = clampf(_base_head_rotation.x, -_head_rotation_limit_rad, _head_rotation_limit_rad)

func _calculate_free_look_rotation(relative: Vector2) -> void:
	_free_look_rotation.x -= relative.y * (_mouse_sensitivity_rad * free_look_sensitivity_multiplier)
	_free_look_rotation.y -= relative.x * (_mouse_sensitivity_rad * free_look_sensitivity_multiplier)

	_free_look_rotation.x = clampf(_free_look_rotation.x, -_free_look_rotation_limit_rad.x, _free_look_rotation_limit_rad.x)
	_free_look_rotation.y = clampf(_free_look_rotation.y, -_free_look_rotation_limit_rad.y, _free_look_rotation_limit_rad.y)

func _free_look_return(delta) -> void:
	if !_input_handler.freelook_held:
		_free_look_rotation.x = lerpf(_free_look_rotation.x, 0.0, free_look_return_speed * delta)
		_free_look_rotation.y = lerpf(_free_look_rotation.y, 0.0, free_look_return_speed * delta)

func _calculate_head_rotation(base, free_look) -> void:
	_head_rotation = base + free_look

	_head_rotation.x = clampf(_head_rotation.x, -_head_rotation_limit_rad, _head_rotation_limit_rad)

	_head.rotation = Vector3(_head_rotation.x, _head_rotation.y, 0.0)

func _calculate_camera_fov(delta: float, movement_speed: float) -> void:
	var idle_floor_speed: float = _movement_controller.walk_speed + _movement_controller.crouch_speed
	var fov_speed_buff: float = (movement_speed - idle_floor_speed) * fov_speed_buff_factor

	_camera_fov = default_camera_fov + fov_speed_buff

	_camera.fov = lerpf(_camera.fov, _camera_fov, fov_interpolation_speed * delta)
