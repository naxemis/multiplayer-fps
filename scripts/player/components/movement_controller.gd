class_name MovementController
extends Node

# Signals

# Enums and constants

# @export vars
@export_category("Velocity Timeout")
@export var time_before_velocity_timeout: float = 0.5 # how long player have to walk into wall before timeout

# Public vars
var velocity_timeout: bool = false # true - player is walking into wall for too long time

# Private vars (_)
var _context: PlayerContext

# @onready vars

# _init / _ready

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func physics_process(delta: float, context: PlayerContext) -> void:
	_context = context

	_get_velocity_timeout(delta)

# Public methods (component APIs)
var _velocity_timeout_time_left: float = 0.0 # current time before timeout is set to true

# Private methods (_)
func _is_blocked_on_wall() -> bool:
	return _context.is_on_floor and _context.is_on_wall and _context.velocity.z == 0 and _context.velocity.x == 0

func _get_velocity_timeout(delta) -> void:
	_velocity_timeout_time_left = clampf(_velocity_timeout_time_left, 0.0, time_before_velocity_timeout)
	
	if _is_blocked_on_wall():
		_velocity_timeout_time_left -= delta
	else:
		_velocity_timeout_time_left = time_before_velocity_timeout
	
	if _velocity_timeout_time_left <= 0:
		velocity_timeout = true
	else:
		velocity_timeout = false
