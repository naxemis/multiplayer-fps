class_name Player
extends CharacterBody3D

# TODO (REFACTOR PLAN): 
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

#region Velocity Timeout

#endregion

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
	
	if _context.state_machine._current_state == _context.state_machine.MovementStates.CROUCH:
		collision_blend_amount = lerpf(collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif _context.state_machine._current_state == _context.state_machine.MovementStates.SLIDE:
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
	_context.state_machine.MovementStates.IDLE: idle_stamina_recovery,
	_context.state_machine.MovementStates.CROUCH: crouch_stamina_recovery,
	_context.state_machine.MovementStates.WALK: walk_stamina_recovery,
	_context.state_machine.MovementStates.RUN: run_stamina_recovery,
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
	
	match _context.state_machine._current_state:
		_context.state_machine.MovementStates.IDLE:
			stamina += idle_stamina_recovery * delta
		_context.state_machine.MovementStates.CROUCH:
			stamina += crouch_stamina_recovery * delta
		_context.state_machine.MovementStates.WALK:
			stamina += walk_stamina_recovery * delta
		_context.state_machine.MovementStates.RUN:
			stamina += run_stamina_recovery * delta
		_context.state_machine.MovementStates.SLIDE:
			stamina -= slide_stamina_drain * delta
	
	if !is_on_floor():
		stamina += in_air_stamina_recovery * delta
	
	if stamina <= stamina_safe_zone:
		%StaminaBar.tint_progress = Color(188, 0, 0)
	else:
		%StaminaBar.tint_progress = Color(255, 255, 255)
	
	%StaminaBar.value = stamina
	%StaminaBar.max_value = max_stamina
#endregion

#region Movement Directions and Inertia
# in what direction player is trying to move
var movement_directions: Vector3
func get_movement_directions() -> void:
	movement_directions.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	movement_directions.z = Input.get_action_strength("back") - Input.get_action_strength("forward")

@export_category("Movement Inertia")
var inertia_movement_directions: Vector3
var current_inertia: float
@export var on_ground_inertia: float = 8.0
@export var in_air_inertia: float = 4.0
func calulcate_movement_inertia(delta) -> void:
	if is_on_floor():
		current_inertia = on_ground_inertia
	else:
		current_inertia = in_air_inertia
	
	inertia_movement_directions.x = lerpf(inertia_movement_directions.x, movement_directions.x, current_inertia * delta)
	inertia_movement_directions.z = lerpf(inertia_movement_directions.z, movement_directions.z, current_inertia * delta)
#endregion

#region Gravity, Jumping and Double Jumping
@export_category("Gravity")
# applies gravity to player's body, when it's not on floor
@export var gravity_force: float = 18.0
func _gravity(delta) -> void:
	if !is_on_floor():
		movement_directions.y -= gravity_force * delta
	else:
		pass

@export_category("Jumping")
# adds jumping mechanic to player's movement
@export var jump_velocity: float = 7.5
func _jump() -> void:
	movement_directions.y = 0
	movement_directions.y += jump_velocity
		
	_context.state_machine.consume_coyote()
		
	one_time_stamina_drain(jump_stamina_drain)

@export_category("Double Jumping")
@export var double_jump_multiplier: float = 0.7
@export var can_double_jump_after_wall_jump: bool = false
func _double_jump() -> void:
	if movement_directions.y < 0:
		movement_directions.y = 0.0
		
	movement_directions.y += jump_velocity * double_jump_multiplier
		
	one_time_stamina_drain(double_jump_stamina_drain)
		
	reset_wall_jumping_directions()
#endregion

#region Wall Jumping
@export_category("Wall Jumping")
var wall_jump_direction: Vector3
@export var vertical_jump_multiplier: float = 0.85
@export var min_vertical_jump: float = 5.0
@export var max_vertical_jump: float = 7.5
func reset_wall_jumping_directions() -> void:
	wall_jump_direction = Vector3(1, 0, 1)

func _wall_jump() -> void:
	if _context.state_machine._can_enter_wall_jump():
		reset_wall_jumping_directions()
		
		# calculates and clamps vertical jump force after wall jumping
		var vertical_jump: float = _context.movement_controller.movement_speed * vertical_jump_multiplier 
		vertical_jump = clampf(vertical_jump, min_vertical_jump, max_vertical_jump)
		
		# gives player slight jump in vertical direction depending on his speed; more speed = bigger jump
		movement_directions.y = 0.0
		movement_directions.y += vertical_jump
		
		# direction of wall jump
		if !Input.is_action_pressed("change_wall_jump_direction"): # player wants to jump in same direction he jumped from
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * movement_directions)
		else: # player wants to "bounce" from a wall
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * -movement_directions)
		
		one_time_stamina_drain(wall_jump_stamina_drain)
	
	if is_on_floor():
		reset_wall_jumping_directions()
#endregion

func movement_velocity() -> void:
	var transform_x: Vector3 = global_transform.basis.x * inertia_movement_directions.x
	var transform_y: Vector3 = global_transform.basis.y * movement_directions.y
	var transform_z: Vector3 = global_transform.basis.z * inertia_movement_directions.z
	
	if _context.state_machine._current_state != _context.state_machine.MovementStates.WALL_JUMP:
		velocity = (transform_x + transform_z) * _context.movement_controller.movement_speed + transform_y
	else:
		velocity = wall_jump_direction * _context.movement_controller.movement_speed + transform_y
		
	
	move_and_slide()

var current_movement_logic: Callable

func _on_state_changed(new_state):
	var states := _context.state_machine.MovementStates
	
	match new_state:
		states.IDLE, states.CROUCH:
			current_movement_logic = _context.movement_controller._crouch_or_other
		states.WALK:
			current_movement_logic = _context.movement_controller._walk
		states.RUN:
			current_movement_logic = _context.movement_controller._run
		states.SLIDE:
			current_movement_logic = _context.movement_controller._slide
		states.JUMP: _jump()
		states.DOUBLE_JUMP: _double_jump()
		states.WALL_JUMP: _wall_jump()

var _context: PlayerContext = PlayerContext.new()

# TODO: Move context initialization to a function in PlayerContext and then call it from corresponding engine callbacks in Player script

func _init_context() -> void:
	_context.head = %Head
	_context.camera = %Camera
	
	_context.camera_controller = $CameraController
	_context.state_machine = $MovementStateMachine
	_context.movement_controller = $MovementController
	
	_context.stamina_safe_zone = stamina_safe_zone
	_context.jump_stamina_drain = jump_stamina_drain
	_context.double_jump_stamina_drain = double_jump_stamina_drain
	_context.wall_jump_stamina_drain = wall_jump_stamina_drain
	_context.body_rotation = rotation

func _build_process_context() -> void:
	self.rotation = _context.body_rotation
	
func _build_physics_context() -> void:
	_context.is_on_floor = is_on_floor()
	_context.is_on_wall = is_on_wall()
	_context.is_on_wall_only = is_on_wall_only()
	_context.velocity = velocity
	_context.movement_directions = movement_directions
	_context.stamina = stamina
	_context.floor_normal = get_floor_normal()
	_context.forward_vector = -transform.basis.z

func _unhandled_input(event: InputEvent) -> void:
	_context.camera_controller.handle_input(event)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	_init_context()
	
	_context.camera_controller.ready(_context)
	_context.state_machine.ready(_context)
	_context.movement_controller.ready(_context)
	
	current_movement_logic = _context.movement_controller._crouch_or_other
	
	_context.state_machine.state_changed.connect(_on_state_changed)

@onready var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLE_JUMP", "WALL_JUMP", "FALL"]
func _process(delta: float) -> void:
	_context.camera_controller.process(delta)
	
	_build_process_context()
		
	%Debug.text = str(
		"FPS: ", Engine.get_frames_per_second(), "\n",
		"Velocity: ", round(velocity), "\n",
		"Movement Speed: ", snappedf(_context.movement_controller.movement_speed, 0.1), "\n",
		"Walk Speed: ", snappedf(_context.movement_controller.walk_speed, 0.01), "\n",
		"Run Speed: ", snappedf(_context.movement_controller.run_speed, 0.01), "\n",
		"Slide Speed: ", snappedf(_context.movement_controller.slide_speed, 0.01), "\n",
		"Movement State: ", movement_states_array[_context.state_machine._current_state], "\n",
		"Velocity Timeout Time Left: ", _context.movement_controller._velocity_timeout_left, "\n",
		"Stamina: ", snappedf(stamina, 0.1), "\n",
		"On Floor: ", is_on_floor(), "\n",
		"On Wall: ", is_on_wall(), "\n",
		"Camera FOV: ", snappedf(%Camera.fov, 0.1), "\n",
		"Coyote Time Left: ", snappedf(_context.state_machine._coyote_time_left, 0.01)
	)

func _physics_process(delta: float) -> void:
	collision_shape_animations(delta)
	calculate_stamina(delta)
	get_movement_directions()
	calulcate_movement_inertia(delta)

	_build_physics_context()

	_context.state_machine.physics_process(delta) 

	current_movement_logic.call()
	
	_context.movement_controller.physics_process(delta)
	
	var floor_speed: float = _context.movement_controller.crouch_speed + _context.movement_controller.walk_speed + _context.movement_controller.run_speed
	var speed_before_inertia: float = maxf(0.0, floor_speed + _context.movement_controller.slide_speed)

	_context.movement_controller.movement_speed = lerpf(_context.movement_controller.movement_speed, speed_before_inertia, 1.0 - exp(-_context.movement_controller.speed_inertia * delta))

	_gravity(delta)
	movement_velocity()
	
