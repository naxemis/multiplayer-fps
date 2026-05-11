# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

class_name Player
extends CharacterBody3D

# TODO (REFACTOR PLAN) [IN PROGRESS]: 
# TODO: Refactor the code by splitting it into multiple scripts and using composition instead of having everything in one script; 
# TODO: For example, create separate scripts for handling movement states, stamina, collision shape animations, etc. 
# TODO: Then have the Player script use those components to manage the player's behavior. 
# TODO: This will make the code more organized, easier to read, and maintainable in the long run.
#
# https://github.com/naxemis/multiplayer-fps/issues/1

# TODO (MOVING UP SLOPES BUG):
# TODO: Movement on slopes is still bugged. Slopes can randomly block players - especially when they are trying to run or slide up them. 
# TODO: This is probably because of the way the movement speed is calculated and how it interacts with the slope.
# TODO: The problem presists even on small slopes, so it is not a problem of the player being blocked by the slope itself.
# TODO: Fix the problem when extracting code to seperate scripts, because it' not clear how to do it without breaking the code even more.

# TODO (COMPONENTS ABSTRACT CLASSES): Add abstraction class for components that contain "pass_context()" method and "process(delta)" and "physics_process(delta)" methods, because it's a common pattern in all components and it would be good to have a blueprint for it.

# TODO (CODE DOCUMENTATION): Write documentation comments in all componets and contexts (same with abstraction classes) for classes, functions and variables

#region Collision Shape Animations
@export_category("Collision Shape Animations")
var collision_blend_amount: float = 0.0

@export var crouch_animation_speed: float = 7.5
@export var slide_animation_speed: float = 10.0

@export var crouch_blend_amount: float = 1.0
@export var slide_blend_amount: float = 2.0
var amount_above_crouch_clamp: float
func collision_shape_animations(delta) -> void:
	collision_blend_amount = clampf(collision_blend_amount, 0.0, slide_blend_amount)
	
	if _state_machine._current_state == _state_machine.MovementStates.CROUCH:
		collision_blend_amount = lerpf(collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif _state_machine._current_state == _state_machine.MovementStates.SLIDE:
		collision_blend_amount = lerpf(collision_blend_amount, slide_blend_amount, slide_animation_speed * delta)
	else:
		if collision_blend_amount <= crouch_blend_amount:
			collision_blend_amount = lerpf(collision_blend_amount, 0.0, crouch_animation_speed * delta)
		elif collision_blend_amount > crouch_blend_amount:
			collision_blend_amount = lerpf(collision_blend_amount, 0.0, slide_animation_speed * delta)
	
	$CollisionAnimationTree["parameters/State Blend/blend_amount"] = collision_blend_amount
#endregion

#region Stamina
@export_category("Movement Stamina")
@export var max_stamina: float = 100.0
@onready var stamina: float = max_stamina

@export var idle_stamina_recovery: float = 25.0
@export var crouch_stamina_recovery: float = 17.5
@export var walk_stamina_recovery: float = 12.5
@export var run_stamina_recovery: float = 7.5
@export var in_air_stamina_recovery: float = 2.5

@export var slide_stamina_drain: float = 7.5

@export var jump_stamina_drain: float = 5.0
@export var double_jump_stamina_drain: float = 2.5
@export var wall_jump_stamina_drain: float = 2.5

@export var stamina_safe_zone: float = 10.0
func one_time_stamina_drain(value_of_stamina_drain: float) -> void:
	stamina -= value_of_stamina_drain

func calculate_stamina(delta) -> void:
	stamina = clampf(stamina, 0.0, max_stamina)
	
	match _state_machine._current_state:
		_state_machine.MovementStates.IDLE:
			stamina += idle_stamina_recovery * delta
		_state_machine.MovementStates.CROUCH:
			stamina += crouch_stamina_recovery * delta
		_state_machine.MovementStates.WALK:
			stamina += walk_stamina_recovery * delta
		_state_machine.MovementStates.RUN:
			stamina += run_stamina_recovery * delta
		_state_machine.MovementStates.SLIDE:
			stamina -= slide_stamina_drain * delta
	
	if !is_on_floor():
		stamina += in_air_stamina_recovery * delta
	
	if stamina <= stamina_safe_zone:
		$StaminaBar.tint_progress = Color(188, 0, 0)
	else:
		$StaminaBar.tint_progress = Color(255, 255, 255)
	
	$StaminaBar.value = stamina
	$StaminaBar.max_value = max_stamina
#endregion

var current_movement_logic: Callable

func _on_state_changed(new_state):
	var states := _state_machine.MovementStates

	print(new_state)

	match new_state:
		states.IDLE, states.CROUCH: current_movement_logic = _movement_controller._crouch_or_other
		states.WALK: current_movement_logic = _movement_controller._walk
		states.RUN: current_movement_logic = _movement_controller._run
		states.SLIDE: current_movement_logic = _movement_controller._slide
		states.JUMP: _movement_controller.jump()
		states.DOUBLE_JUMP: _movement_controller.double_jump()
		states.WALL_JUMP: _movement_controller.wall_jump()

var _player_context_module: PlayerContextModule = PlayerContextModule.new()
var _state_machine: StateMachine
var _movement_controller: MovementController
var _camera_controller: CameraController

func _unhandled_input(event: InputEvent) -> void:
	_camera_controller.handle_input(event)

var _player_context_data: PlayerContextData

func _create_context_data() -> void:
	_player_context_data = PlayerContextData.new()


func _init_player_node_refs_context_data() -> void:
	_player_context_data.node_refs.player = self
	_player_context_data.node_refs.head = $Head
	_player_context_data.node_refs.camera = %Camera
	
	_player_context_module.init_node_refs_data(_player_context_data.node_refs)

func _init_player_components_context_data() -> void:
	_player_context_data.components.camera_controller = $CameraController
	_player_context_data.components.state_machine = $StateMachine
	_player_context_data.components.movement_controller = $MovementController

	_player_context_module.init_components_data(_player_context_data.components)

func _pass_player_context_module_to_components() -> void:
	_player_context_module.components.camera_controller.pass_player_context_module(_player_context_module)
	_player_context_module.components.state_machine.pass_player_context_module(_player_context_module)
	_player_context_module.components.movement_controller.pass_player_context_module(_player_context_module)

	_camera_controller = _player_context_module.components.camera_controller
	_state_machine = _player_context_module.components.state_machine
	_movement_controller = _player_context_module.components.movement_controller

func _build_player_context_data() -> void:
	_create_context_data()

	_init_player_node_refs_context_data()
	_init_player_components_context_data()
	_pass_player_context_module_to_components()

func _connect_state_machine_signal() -> void:
	current_movement_logic = _movement_controller._crouch_or_other

	_state_machine.state_changed.connect(_on_state_changed)

func _debug_text() -> String:
	return str(
		"FPS: ", Engine.get_frames_per_second(), "\n",
		"Velocity: ", round(velocity), "\n",
		"Movement Speed: ", snappedf(_movement_controller.movement_speed, 0.1), "\n",
		"Walk Speed: ", snappedf(_movement_controller.walk_speed, 0.01), "\n",
		"Run Speed: ", snappedf(_movement_controller.run_speed, 0.01), "\n",
		"Slide Speed: ", snappedf(_movement_controller.slide_speed, 0.01), "\n",
		"Movement State: ", movement_states_array[_state_machine._current_state], "\n",
		"Velocity Timeout Time Left: ", _movement_controller._velocity_timeout_left, "\n",
		"Stamina: ", snappedf(stamina, 0.1), "\n",
		"On Floor: ", is_on_floor(), "\n",
		"On Wall: ", is_on_wall(), "\n",
		"Camera FOV: ", snappedf(%Camera.fov, 0.1), "\n",
		"Coyote Time Left: ", snappedf(_state_machine._coyote_time_left, 0.01)
	)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_build_player_context_data()
	_connect_state_machine_signal()

@onready var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLE_JUMP", "WALL_JUMP", "FALL"]
func _process(_delta: float) -> void:
	$Debug.text = _debug_text()

func _physics_process(delta: float) -> void:
	collision_shape_animations(delta) # TODO (COLLISION ANIMATOR): Move to collision_animator component
	calculate_stamina(delta) # TODO (STAMINA MANAGER): Move to stamina_manager component

	current_movement_logic.call()

	velocity = _movement_controller.compute_movement_velocity()
	move_and_slide()
	