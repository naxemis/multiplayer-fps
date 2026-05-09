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

# TODO (CODE DOCUMENTATION) [IN PROGRESS]: Write documentation comments in all componets and contexts (same with abstraction classes) for classes, functions and variables

# TODO (PROJECT LICENSE): Add license to all scripts and project root

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
	
	if _player_context_module.components.state_machine._current_state == _player_context_module.components.state_machine.MovementStates.CROUCH:
		collision_blend_amount = lerpf(collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif _player_context_module.components.state_machine._current_state == _player_context_module.components.state_machine.MovementStates.SLIDE:
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

var stamina_recovery := {
	_player_context_module.components.state_machine.MovementStates.IDLE: idle_stamina_recovery,
	_player_context_module.components.state_machine.MovementStates.CROUCH: crouch_stamina_recovery,
	_player_context_module.components.state_machine.MovementStates.WALK: walk_stamina_recovery,
	_player_context_module.components.state_machine.MovementStates.RUN: run_stamina_recovery,
}

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
	
	match _player_context_module.components.state_machine._current_state:
		_player_context_module.components.state_machine.MovementStates.IDLE:
			stamina += idle_stamina_recovery * delta
		_player_context_module.components.state_machine.MovementStates.CROUCH:
			stamina += crouch_stamina_recovery * delta
		_player_context_module.components.state_machine.MovementStates.WALK:
			stamina += walk_stamina_recovery * delta
		_player_context_module.components.state_machine.MovementStates.RUN:
			stamina += run_stamina_recovery * delta
		_player_context_module.components.state_machine.MovementStates.SLIDE:
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

func movement_velocity() -> void:
	var transform_x: Vector3 = global_transform.basis.x * _player_context_module.components.movement_controller.get_inertia_movement_directions().x
	var transform_y: Vector3 = global_transform.basis.y * _player_context_module.components.movement_controller.get_movement_directions().y
	var transform_z: Vector3 = global_transform.basis.z * _player_context_module.components.movement_controller.get_inertia_movement_directions().z
	
	if _player_context_module.components.state_machine._current_state != _player_context_module.components.state_machine.MovementStates.WALL_JUMP:
		velocity = (transform_x + transform_z) * _player_context_module.components.movement_controller.movement_speed + transform_y
	else:
		velocity = _player_context_module.components.movement_controller.get_wall_jump_directions() * _player_context_module.components.movement_controller.movement_speed + transform_y
		
	
	move_and_slide()

var current_movement_logic: Callable

func _on_state_changed(new_state):
	var states := _player_context_module.components.state_machine.MovementStates
	
	print(new_state)
	
	match new_state:
		states.IDLE, states.CROUCH: current_movement_logic = _player_context_module.components.movement_controller._crouch_or_other
		states.WALK: current_movement_logic = _player_context_module.components.movement_controller._walk
		states.RUN: current_movement_logic = _player_context_module.components.movement_controller._run
		states.SLIDE: current_movement_logic = _player_context_module.components.movement_controller._slide
		states.JUMP: _player_context_module.components.movement_controller.jump()
		states.DOUBLE_JUMP: _player_context_module.components.movement_controller.double_jump()
		states.WALL_JUMP: _player_context_module.components.movement_controller.wall_jump()

var _player_context_module: PlayerContextModule = PlayerContextModule.new()

# TODO: Move context initialization to a function in PlayerContextModule and then call it from corresponding engine callbacks in Player script

func _unhandled_input(event: InputEvent) -> void:
	_player_context_module.components.camera_controller.handle_input(event)

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

func _init_player_init_context_data() -> void:
	_player_context_data.init.stamina_safe_zone = stamina_safe_zone
	_player_context_data.init.jump_stamina_drain = jump_stamina_drain
	_player_context_data.init.double_jump_stamina_drain = double_jump_stamina_drain
	_player_context_data.init.wall_jump_stamina_drain = wall_jump_stamina_drain
	
	_player_context_module.init_init_data(_player_context_data.init)

func _update_player_physics_context_data() -> void:
	_player_context_data.physics.is_on_floor = is_on_floor()
	_player_context_data.physics.is_on_wall = is_on_wall()
	_player_context_data.physics.is_on_wall_only = is_on_wall_only()
	_player_context_data.physics.velocity = velocity
	_player_context_data.physics.stamina = stamina
	_player_context_data.physics.floor_normal = get_floor_normal()
	_player_context_data.physics.forward_vector = -transform.basis.z
	
	_player_context_module.update_physics_data(_player_context_data.physics)

func _pass_player_context_module_to_components() -> void:
	_player_context_module.components.camera_controller.pass_player_context_module(_player_context_module)
	_player_context_module.components.state_machine.pass_player_context_module(_player_context_module)
	_player_context_module.components.movement_controller.pass_player_context_module(_player_context_module)

func _build_player_context_data():
	_create_context_data()

	_init_player_node_refs_context_data()
	_init_player_components_context_data()
	_pass_player_context_module_to_components()
	_init_player_init_context_data()
	
	_update_player_physics_context_data()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_build_player_context_data()
	
	current_movement_logic = _player_context_module.components.movement_controller._crouch_or_other
	
	_player_context_module.components.state_machine.state_changed.connect(_on_state_changed)

@onready var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLE_JUMP", "WALL_JUMP", "FALL"]
func _process(delta: float) -> void:
	_player_context_module.components.camera_controller.process(delta)
	
	$Debug.text = str(
		"FPS: ", Engine.get_frames_per_second(), "\n",
		"Velocity: ", round(velocity), "\n",
		"Movement Speed: ", snappedf(_player_context_module.components.movement_controller.movement_speed, 0.1), "\n",
		"Walk Speed: ", snappedf(_player_context_module.components.movement_controller.walk_speed, 0.01), "\n",
		"Run Speed: ", snappedf(_player_context_module.components.movement_controller.run_speed, 0.01), "\n",
		"Slide Speed: ", snappedf(_player_context_module.components.movement_controller.slide_speed, 0.01), "\n",
		"Movement State: ", movement_states_array[_player_context_module.components.state_machine._current_state], "\n",
		"Velocity Timeout Time Left: ", _player_context_module.components.movement_controller._velocity_timeout_left, "\n",
		"Stamina: ", snappedf(stamina, 0.1), "\n",
		"On Floor: ", is_on_floor(), "\n",
		"On Wall: ", is_on_wall(), "\n",
		"Camera FOV: ", snappedf(%Camera.fov, 0.1), "\n",
		"Coyote Time Left: ", snappedf(_player_context_module.components.state_machine._coyote_time_left, 0.01)
	)

func _physics_process(delta: float) -> void:
	_update_player_physics_context_data()

	collision_shape_animations(delta) # TODO (COLLISION ANIMATOR): Move to collision_animator component
	calculate_stamina(delta) # TODO (STAMINA MANAGER): Move to stamina_manager component

	_player_context_module.components.state_machine.physics_process(delta) 

	current_movement_logic.call()
	
	_player_context_module.components.movement_controller.physics_process(delta)
	
	# TODO (MOVEMENT CONTROLLER): Move to movement_controller component
	var floor_speed: float = _player_context_module.components.movement_controller.crouch_speed + _player_context_module.components.movement_controller.walk_speed + _player_context_module.components.movement_controller.run_speed
	var speed_before_inertia: float = maxf(0.0, floor_speed + _player_context_module.components.movement_controller.slide_speed)

	_player_context_module.components.movement_controller.movement_speed = lerpf(_player_context_module.components.movement_controller.movement_speed, speed_before_inertia, 1.0 - exp(-_player_context_module.components.movement_controller.speed_inertia * delta))
	
	movement_velocity() # TODO (MOVEMENT CONTROLLER): Move to movement_controller component
	
