class_name Player
extends CharacterBody3D

# TODO (REFACTOR PLAN): 
# refactor the code by splitting it into multiple scripts and using composition instead of having everything in one script; 
# for example, create separate scripts for handling movement states, stamina, collision shape animations, etc. 
# and then have the Player script use those components to manage the player's behavior. 
# This will make the code more organized, easier to read, and maintainable in the long run.
#
# https://github.com/naxemis/multiplayer-fps/issues/1

#region Velocity Timeout
@export_category("Velocity Timeout")
@export var time_before_velocity_timeout: float = 0.75 # how long player have to walk into wall before timeout
var velocity_timeout_time_left: float = 0.0 # current time before timeout is set to true
var velocity_timeout: bool = false # true - player is walking into wall for too long time
func is_blocked_on_wall() -> bool:
	return is_on_floor() and is_on_wall() and velocity.z == 0 and velocity.x == 0

func get_velocity_timeout(delta) -> void:
	velocity_timeout_time_left = clampf(velocity_timeout_time_left, 0.0, time_before_velocity_timeout)
	
	if is_blocked_on_wall():
		velocity_timeout_time_left -= delta
	else:
		velocity_timeout_time_left = time_before_velocity_timeout
	
	if velocity_timeout_time_left <= 0:
		velocity_timeout = true
	else:
		velocity_timeout = false
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
	
	if movement_state_machine._current_state == movement_state_machine.MovementStates.CROUCH:
		collision_blend_amount = lerpf(collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif movement_state_machine._current_state == movement_state_machine.MovementStates.SLIDE:
		collision_blend_amount = lerpf(collision_blend_amount, slide_blend_amount, slide_animation_speed * delta)
	else:
		if collision_blend_amount <= crouch_blend_amount:
			collision_blend_amount = lerpf(collision_blend_amount, 0.0, crouch_animation_speed * delta)
		elif collision_blend_amount > crouch_blend_amount:
			collision_blend_amount = lerpf(collision_blend_amount, 0.0, slide_animation_speed * delta)
	
	$CollisionAnimationTree["parameters/State Blend/blend_amount"] = collision_blend_amount
#endregion

#region Movement Speed
var movement_speed: float = 0.0

@export_category("Crouching and Walking")
@export var crouch_speed: float = 2.0
@export var walk_speed: float = 2.0
var current_walk_speed: float = 0.0

@export_category("Running")
var run_speed: float = 0.0
@export var max_run_speed: float = 2.5

@export var run_speed_increase: float = 1.0
@export var run_walk_decrease: float = 2.5
@export var run_crouch_decrease: float = 4.0

@export_category("Sliding")
var slide_speed: float = 0.0
@export var max_slide_speed: float = 2.5

@export var slide_buff_multiplier: float = 0.15 # multiplies (after adding slope_interference) slide buff from floor_speed
@export var slope_interference_factor: float = 0.85 # how much slope interference will actually work on calculating slide buff

@export var slide_run_decrease: float = 0.05 # decrease when switching to running
@export var slide_walk_decrease: float = 2.5 # decrease when switching to walking
@export var slide_crouch_decrease: float = 4.0 # decrease when switching to crouching

@export_category("Speed Inertia")
@export var speed_inertia: float = 7.5

func _walk() -> void:
	var delta: float = get_physics_process_delta_time()

	current_walk_speed = walk_speed
	
	run_speed -= run_walk_decrease * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	var floor_speed: float = crouch_speed + current_walk_speed + run_speed
	slide_speed -= floor_speed * slide_walk_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)
	
func _run() -> void:
	var delta: float = get_physics_process_delta_time()

	current_walk_speed = walk_speed
	
	run_speed += run_speed_increase * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	var floor_speed: float = crouch_speed + current_walk_speed + run_speed
	slide_speed -= floor_speed * slide_run_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _slide() -> void:
	var delta: float = get_physics_process_delta_time()

	current_walk_speed = walk_speed
	
	var floor_normal: Vector3 = get_floor_normal()
	var forward_vector: Vector3 = -transform.basis.z
	var calculating_slope: Vector3 = floor_normal * forward_vector
	var slope_interference: float = (calculating_slope.z + calculating_slope.x) * slope_interference_factor
	
	var floor_speed: float = crouch_speed + current_walk_speed + run_speed
	var actual_slide_buff: float = floor_speed * (slide_buff_multiplier + slope_interference)
	
	slide_speed += actual_slide_buff * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

func _crouch_or_other() -> void:
	var delta: float = get_physics_process_delta_time()

	current_walk_speed = 0.0
	
	run_speed -= run_crouch_decrease * delta
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	slide_speed -= slide_crouch_decrease * delta
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)

#region Stamina
@export_category("Movement Stamina")
@export var max_stamina: float = 100.0
@onready var stamina: float = max_stamina

var stamina_recovery := {
	movement_state_machine.MovementStates.IDLE: idle_stamina_recovery,
	movement_state_machine.MovementStates.CROUCH: crouch_stamina_recovery,
	movement_state_machine.MovementStates.WALK: walk_stamina_recovery,
	movement_state_machine.MovementStates.RUN: run_stamina_recovery,
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
	
	match movement_state_machine._current_state:
		movement_state_machine.MovementStates.IDLE:
			stamina += idle_stamina_recovery * delta
		movement_state_machine.MovementStates.CROUCH:
			stamina += crouch_stamina_recovery * delta
		movement_state_machine.MovementStates.WALK:
			stamina += walk_stamina_recovery * delta
		movement_state_machine.MovementStates.RUN:
			stamina += run_stamina_recovery * delta
		movement_state_machine.MovementStates.SLIDE:
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
		
	movement_state_machine.coyote_time_left = 0
		
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
	if movement_state_machine._can_enter_wall_jump():
		reset_wall_jumping_directions()
		
		# calculates and clamps vertical jump force after wall jumping
		var vertical_jump: float = movement_speed * vertical_jump_multiplier 
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
	
	if movement_state_machine._current_state != movement_state_machine.MovementStates.WALL_JUMP:
		velocity = (transform_x + transform_z) * movement_speed + transform_y
	else:
		velocity = wall_jump_direction * movement_speed + transform_y
		
	
	move_and_slide()

var current_movement_logic: Callable = _crouch_or_other

func _on_state_changed(new_state):
	var states := movement_state_machine.MovementStates
	
	match new_state:
		states.IDLE, states.CROUCH:
			current_movement_logic = _crouch_or_other
		states.WALK:
			current_movement_logic = _walk
		states.RUN:
			current_movement_logic = _run
		states.SLIDE:
			current_movement_logic = _slide
		states.JUMP: _jump()
		states.DOUBLE_JUMP: _double_jump()
		states.WALL_JUMP: _wall_jump()

@onready var camera_controller: CameraController = $CameraController
@onready var movement_state_machine: MovementStateMachine = $MovementStateMachine

func _unhandled_input(event: InputEvent) -> void:
	camera_controller.handle_input(event)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	camera_controller.set_references(self, $Head, %Camera)
	movement_state_machine.set_references(self)
	
	movement_state_machine.state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	camera_controller.process(delta, movement_speed)
		
	var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLE_JUMP", "WALL_JUMP", "FALL"]
	%Debug.text = str("FPS:", Engine.get_frames_per_second(), " | Velocity: ", round(velocity), " | Movement Speed: ", snappedf(movement_speed, 0.1), " | Movement State: ", movement_states_array[movement_state_machine._current_state], " | Velocity Timeout Time Left: ", velocity_timeout_time_left, " | Current Inertia: ", current_inertia, " | Camera FOV: ", snappedf(%Camera.fov, 0.1), " | Coyote Time Left: ", snappedf(movement_state_machine.coyote_time_left, 0.01))

func _physics_process(delta: float) -> void:
	get_velocity_timeout(delta)
	collision_shape_animations(delta)
	calculate_stamina(delta)
	get_movement_directions()
	calulcate_movement_inertia(delta)

	movement_state_machine.process(delta) 

	current_movement_logic.call()
		
	var floor_speed: float = crouch_speed + current_walk_speed + run_speed
	var speed_before_inertia: float = floor_speed + slide_speed
		
	movement_speed = lerpf(movement_speed, speed_before_inertia, speed_inertia * delta)

	_gravity(delta)
	movement_velocity()
