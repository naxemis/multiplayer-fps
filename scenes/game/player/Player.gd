class_name Player
extends CharacterBody3D

#region Head and Body rotation
@export_category("Mouse Movement")
@export var mouse_sensitivity: float = 0.075

func body_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		# connects mouse movement to head rotation
		self.rotation.y -= event.relative.x * deg_to_rad(mouse_sensitivity)
		
		# wraps player's body rotation to left and right direction
		const rotation_min: float = deg_to_rad(0.0)
		const rotation_max: float = deg_to_rad(360.0)
		self.rotation.y = wrapf(self.rotation.y, rotation_min, rotation_max)

var head_rotation: Vector3
@export var head_rotation_limit: float = 90.0
func get_head_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		# connects mouse movement to free look rotation
		head_rotation.x -= event.relative.y * deg_to_rad(mouse_sensitivity)
		
		# limits player's head rotation in up and down direction
		head_rotation.x = clampf(head_rotation.x, -deg_to_rad(head_rotation_limit), deg_to_rad(head_rotation_limit))

@export_category("Camera Freelook")
var free_look_rotation: Vector3
@export var free_look_rotation_limit: Vector2 = Vector2(35, 50)
@export var free_look_sensitivity_multiplier: float = 4.0
func get_free_look_rotation(event) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("free_look"):
		# connects mouse movement to free look rotation
		free_look_rotation.x -= event.relative.y * deg_to_rad(mouse_sensitivity * free_look_sensitivity_multiplier)
		free_look_rotation.y -= event.relative.x * deg_to_rad(mouse_sensitivity * free_look_sensitivity_multiplier)
		
		# limits player's free look rotation in up and down direction
		free_look_rotation.x = clampf(free_look_rotation.x, -deg_to_rad(free_look_rotation_limit.x), deg_to_rad(free_look_rotation_limit.x))
		free_look_rotation.y = clampf(free_look_rotation.y, -deg_to_rad(free_look_rotation_limit.y), deg_to_rad(free_look_rotation_limit.y))

@export var free_look_return_speed: float = 12.5
func free_look_return(delta) -> void:
	if !Input.is_action_pressed("free_look"):
		free_look_rotation.x = lerpf(free_look_rotation.x, 0.0, free_look_return_speed * delta)
		free_look_rotation.y = lerpf(free_look_rotation.y, 0.0, free_look_return_speed * delta)

# combines head_rotation variable value and free_look_rotation variable value and sets it to %Head.rotation
func set_head_rotation() -> void:
	%Head.rotation = head_rotation + free_look_rotation # combines values
	
	# limits player's head rotation in up and down direction
	%Head.rotation.x = clampf(%Head.rotation.x, -deg_to_rad(head_rotation_limit), deg_to_rad(head_rotation_limit))
#endregion

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

#region Movement States
# identifies in what movement state player is currently in
enum MovementStates {IDLE, WALK, RUN, CROUCH, SLIDE, JUMP, DOUBLEJUMP, WALLJUMP}

var movement_state: int = MovementStates.IDLE

@onready var uncrouch_ray_cast_colliding: bool
@onready var unslide_ray_cast_colliding: bool
func can_player_stand_up() -> void:
	uncrouch_ray_cast_colliding = $CrouchRayCast.is_colliding()
	unslide_ray_cast_colliding = $SlideRayCast.is_colliding()

@export_category("Coyote Time")
@export var default_coyote_time: float = 0.15
var coyote_time_left: float = 0.0
var is_coyote_time_active: bool = true
func coyote_time(delta: float) -> void:
	coyote_time_left = clampf(coyote_time_left, 0.0, default_coyote_time)

	if is_on_floor():
		coyote_time_left = default_coyote_time
	else:
		coyote_time_left -= delta
	
	if coyote_time_left >= 0:
		is_coyote_time_active = true
	else:
		is_coyote_time_active = false

func get_idle_state() -> bool:
	return (movement_directions.z == 0 and movement_directions.x == 0 and is_on_floor() and !uncrouch_ray_cast_colliding) or velocity_timeout

func get_walk_state() -> bool:
	return (movement_directions.z != 0 or movement_directions.x != 0) and is_on_floor() and (movement_state != MovementStates.JUMP or movement_state != MovementStates.DOUBLEJUMP) and !uncrouch_ray_cast_colliding and !velocity_timeout

func get_run_state() -> bool:
	return Input.is_action_pressed("run") and movement_directions.z < 0 and is_on_floor() and !uncrouch_ray_cast_colliding and !velocity_timeout and is_coyote_time_active

func get_crouch_state() -> bool:
	return ((Input.is_action_pressed("crouch") and is_on_floor()) and !unslide_ray_cast_colliding) or uncrouch_ray_cast_colliding

func get_slide_state() -> bool:
	return Input.is_action_pressed("slide") and is_on_floor() and movement_directions.z < 0 and !velocity_timeout and stamina > 0

func get_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and is_on_floor() and movement_state != MovementStates.CROUCH and stamina - jump_stamina_drain > 0 and stamina > stamina_safe_zone

func get_double_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and !is_on_floor() and can_double_jump and !get_walk_state() and stamina - double_jump_stamina_drain > 0 and stamina > stamina_safe_zone

func get_wall_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and is_on_wall_only() and (movement_directions.z != 0 or movement_directions.x != 0) and stamina - wall_jump_stamina_drain >= 0 and stamina > stamina_safe_zone

func change_movement_state(new_movement_state) -> void:
	movement_state = new_movement_state

func set_movement_states() -> void:
	if get_jump_state():
		change_movement_state(MovementStates.JUMP)
	elif get_wall_jump_state():
		change_movement_state(MovementStates.WALLJUMP)
	elif get_double_jump_state():
		change_movement_state(MovementStates.DOUBLEJUMP)
	elif get_slide_state():
		if stamina > stamina_safe_zone: # player can only slide if stamina is greater than it's safe zone
			change_movement_state(MovementStates.SLIDE)
		else: # but if player is already sliding when stamina is under it's safe zone, then don't change his movement_state
			movement_state = movement_state
	elif get_run_state():
		change_movement_state(MovementStates.RUN)
	elif get_crouch_state():
		change_movement_state(MovementStates.CROUCH)
	elif get_walk_state():
		change_movement_state(MovementStates.WALK)
	elif get_idle_state():
		change_movement_state(MovementStates.IDLE)
#endregion

#region Camera FOV
@export_category("Camera FOV")
var camera_fov: float
@export var default_camera_fov: float = 59.0

@export var speed_fov_buff_factor: float = 2.5
var speed_fov_buff: float = 0.0
func calculate_camera_fov(delta) -> void:
	# calculate default camera fov
	var base_camera_fov: float = default_camera_fov - ((walk_speed + crouch_speed) * speed_fov_buff_factor)
	
	# calculate speed fov buff
	speed_fov_buff = movement_speed * speed_fov_buff_factor
	
	# combine fov buffs
	camera_fov = base_camera_fov + speed_fov_buff
	
	# interpolate camera fov
	%Camera.fov = camera_fov
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
	
	if movement_state == MovementStates.CROUCH:
		collision_blend_amount = lerpf(collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif movement_state == MovementStates.SLIDE:
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

func calculate_movement_speed(delta) -> void:
	# walk speed
	if movement_state != MovementStates.CROUCH:
		current_walk_speed = walk_speed
	else:
		current_walk_speed = 0.0
	
	# run speed
	run_speed = clampf(run_speed, 0.0, max_run_speed)
	
	if movement_state == MovementStates.RUN:
		run_speed += run_speed_increase * delta
	elif movement_state == MovementStates.JUMP or movement_state == MovementStates.DOUBLEJUMP or movement_state == MovementStates.WALLJUMP or movement_state == MovementStates.SLIDE:
		pass
	elif movement_state == MovementStates.WALK:
		run_speed -= run_walk_decrease * delta
	else:
		run_speed -= run_crouch_decrease * delta
	
	# slide speed
	slide_speed = clampf(slide_speed, 0.0, max_slide_speed)
	
	var calculating_slope_interference: Vector3 = get_floor_normal() * -transform.basis.z
	var slope_interference: float = (calculating_slope_interference.z + calculating_slope_interference.x) * slope_interference_factor
	
	var floor_speed: float = crouch_speed + current_walk_speed + run_speed
	var actual_slide_buff_multiplier: float = slide_buff_multiplier + slope_interference
	var slide_buff: float = floor_speed * actual_slide_buff_multiplier
	
	if movement_state == MovementStates.SLIDE:
		slide_speed += slide_buff * delta
	elif movement_state == MovementStates.JUMP or movement_state == MovementStates.DOUBLEJUMP or movement_state == MovementStates.WALLJUMP:
		pass
	elif movement_state == MovementStates.RUN:
		slide_speed -= floor_speed * slide_run_decrease * delta
	elif movement_state == MovementStates.WALK:
		slide_speed -= floor_speed * slide_walk_decrease * delta
	else:
		slide_speed -= slide_crouch_decrease * delta
	
	# speed
	var speed_before_inertia: float = floor_speed + slide_speed
	
	movement_speed = lerpf(movement_speed, speed_before_inertia, speed_inertia * delta) # movement speed after adding inertia
#endregion

#region Stamina
var stamina: float = 100.0
@export var max_stamina: float = 100.0

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
	
	match movement_state:
		MovementStates.IDLE:
			stamina += idle_stamina_recovery * delta
		MovementStates.CROUCH:
			stamina += crouch_stamina_recovery * delta
		MovementStates.WALK:
			stamina += walk_stamina_recovery * delta
		MovementStates.RUN:
			stamina += run_stamina_recovery * delta
		MovementStates.SLIDE:
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

var inertia_movement_directions: Vector3
var current_inertia: float
@export var on_ground_inertia: float = 10.0
@export var in_air_inertia: float = 5.0
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
func gravity(delta) -> void:
	if !is_on_floor():
		movement_directions.y -= gravity_force * delta
	else:
		movement_directions.y = 0.0

@export_category("Jumping")
# adds jumping mechanic to player's movement
@export var jump_velocity: float = 7.5
func jump() -> void:
	if get_jump_state():
		movement_directions.y += jump_velocity
		
		one_time_stamina_drain(jump_stamina_drain)

@export_category("Double Jumping")
@export var double_jump_multiplier: float = 0.7
var can_double_jump: bool = true
var double_jumping: bool = false
func double_jump(delta) -> void:
	if is_on_floor():
		can_double_jump = true
		double_jumping = false
	
	if get_double_jump_state():
		if movement_directions.y < 0:
			movement_directions.y = 0.0
		
		movement_directions.y += jump_velocity * double_jump_multiplier
		can_double_jump = false
		double_jumping = true
		
		one_time_stamina_drain(double_jump_stamina_drain)
		
		reset_wall_jumping_directions()
#endregion

#region Wall Jumping
@export_category("Wall Jumping")
var wall_jump_direction: Vector3
@export var vertical_jump_factor: float = 1.5
@export var max_vertical_jump_factor: float = 1.0
func reset_wall_jumping_directions() -> void:
	wall_jump_direction = Vector3(1, 0, 1)

func wall_jumping() -> void:
	if get_wall_jump_state():
		reset_wall_jumping_directions()
		
		# calculates and clamps vertical jump force after wall jumping
		var vertical_jump: float = movement_speed * vertical_jump_factor 
		vertical_jump = clampf(vertical_jump, 0.0, jump_velocity * max_vertical_jump_factor)
		
		# gives player slight jump in vertical direction depending on his speed; more speed = bigger jump
		movement_directions.y = 0.0
		movement_directions.y += movement_speed * vertical_jump_factor
		
		# direction of wall jump
		if !Input.is_action_pressed("change_wall_jump_direction"): # player wan't to "bounce" from a wall
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * movement_directions)
		else: # player want to jump in same direction he jumped from
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * -movement_directions)
		
		one_time_stamina_drain(wall_jump_stamina_drain)
	
	if is_on_floor():
		reset_wall_jumping_directions()
#endregion

func movement_velocity() -> void:
	var transform_x: Vector3 = global_transform.basis.x * inertia_movement_directions.x
	var transform_y: Vector3 = global_transform.basis.y * movement_directions.y
	var transform_z: Vector3 = global_transform.basis.z * inertia_movement_directions.z
	
	if movement_state != MovementStates.WALLJUMP:
		velocity = (transform_x + transform_z) * movement_speed + transform_y
	else:
		velocity = wall_jump_direction * movement_speed + transform_y
		
	
	move_and_slide()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	body_rotation(event)
	get_head_rotation(event)
	get_free_look_rotation(event)

func _process(delta: float) -> void:
	free_look_return(delta)
	set_head_rotation()
	
	get_velocity_timeout(delta)
	
	can_player_stand_up()
	
	coyote_time(delta)
	
	set_movement_states()
	
	calculate_camera_fov(delta)
	
	collision_shape_animations(delta)
	
	calculate_movement_speed(delta)
	
	calculate_stamina(delta)
	
	get_movement_directions()
	calulcate_movement_inertia(delta)
	
	gravity(delta)
	jump()
	double_jump(delta)
	
	wall_jumping()
	
	movement_velocity()
	
	var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLEJUMP", "WALLJUMP"]
	%Debug.text = str("Velocity: ", round(velocity), " | Movement Speed: ", snappedf(movement_speed, 0.1), " | Movement State: ", movement_states_array[movement_state], " | Velocity Timeout Time Left: ", velocity_timeout_time_left, " | Current Inertia: ", current_inertia, " | Camera FOV: ", snappedf(%Camera.fov, 0.1), " | Coyote Time Left: ", is_coyote_time_active, snappedf(coyote_time_left, 0.01))
