class_name MovementController
extends Node

# TODO: Extract movement directions logic from player.gd script to this component

# TODO: Extract intertia logic from player.gd script to this component

# TODO: Extract velocity calculation logic from player.gd script to this component

# Signals

# Enums and constants

# @export vars
@export_category("Velocity Timeout")
@export var time_before_velocity_timeout: float = 0.5 # how long player have to walk into wall before timeout

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

@export var slide_buff_multiplier: float = 0.15 # multiplies (after adding slope_interference) slide buff from floor_speed
@export var slope_uphill_brake_factor: float = 0.85 # how much uphill brakes slide
@export var slope_downhill_boost_factor: float = 0.5 # how much downhill boosts slide

@export var slide_run_decrease: float = 0.05 # decrease when switching to running
@export var slide_walk_decrease: float = 2.5 # decrease when switching to walking
@export var slide_crouch_decrease: float = 4.0 # decrease when switching to crouching

@export_category("Speed Inertia")
@export var speed_inertia: float = 7.5

# Public vars
var velocity_timeout: bool = false # true - player is walking into wall for too long time

# Private vars (_)
var _context: PlayerContext

# @onready vars

# _init / _ready
func ready(context: PlayerContext) -> void:
	_context = context

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func physics_process(delta: float) -> void:
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

#region Movement Speed
var movement_speed: float = 0.0

var run_speed: float = 0.0

var slide_speed: float = 0.0

func _walk() -> void:
	var delta: float = get_physics_process_delta_time()

	run_speed -= run_walk_decrease * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	var floor_speed: float = crouch_speed + walk_speed + run_speed
	slide_speed -= floor_speed * slide_walk_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)
	
func _run() -> void:
	var delta: float = get_physics_process_delta_time()

	run_speed += run_speed_increase * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	var floor_speed: float = crouch_speed + walk_speed + run_speed
	slide_speed -= floor_speed * slide_run_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _slide() -> void:
	var delta: float = get_physics_process_delta_time()

	var calculating_slope: Vector3 = _context.floor_normal * _context.forward_vector
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
	
	slide_speed -= slide_crouch_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)
