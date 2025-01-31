class_name Player

extends CharacterBody3D

@export_category("Mouse")
@export var mouse_sensitivity: float = 0.075

func body_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		# connects mouse movement to head rotation
		self.rotation.y -= event.relative.x * deg_to_rad(mouse_sensitivity)
		
		# wraps player's body rotation to left and right direction
		const rotation_min: float = deg_to_rad(0)
		const rotation_max: float = deg_to_rad(360)
		self.rotation.y = wrapf(self.rotation.y, rotation_min, rotation_max)

var head_rotation: Vector3
func get_head_rotation(event) -> void:
	if event is InputEventMouseMotion and !Input.is_action_pressed("free_look"):
		# connects mouse movement to free look rotation
		head_rotation.x -= event.relative.y * deg_to_rad(mouse_sensitivity)
		
		# limits player's head rotation in up and down direction
		const rotation_limit: float = deg_to_rad(90)
		head_rotation.x = clampf(head_rotation.x, -rotation_limit, rotation_limit)

var free_look_rotation: Vector3
func get_free_look_rotation(event) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("free_look"):
		# connects mouse movement to free look rotation
		free_look_rotation.x -= event.relative.y * deg_to_rad(mouse_sensitivity)
		free_look_rotation.y -= event.relative.x * deg_to_rad(mouse_sensitivity)
		
		# limits player's free look rotation in up and down direction
		const rotation_limit: Vector2 = Vector2(deg_to_rad(30), deg_to_rad(40))
		free_look_rotation.x = clampf(free_look_rotation.x, -rotation_limit.x, rotation_limit.x)
		free_look_rotation.y = clampf(free_look_rotation.y, -rotation_limit.y, rotation_limit.y)

@export var free_look_return_speed: float = 12.5
func free_look_return(delta) -> void:
	if !Input.is_action_pressed("free_look"):
		free_look_rotation.x = lerpf(free_look_rotation.x, 0.0, free_look_return_speed * delta)
		free_look_rotation.y = lerpf(free_look_rotation.y, 0.0, free_look_return_speed * delta)

# combines head_rotation vairable value and free_look_rotation vairable value and sets it to %Head.rotation
func set_head_rotation() -> void:
	%Head.rotation = head_rotation + free_look_rotation # combines values
	
	# limits player's head rotation in up and down direction
	const rotation_limit: float = deg_to_rad(90)
	%Head.rotation.x = clampf(%Head.rotation.x, -rotation_limit, rotation_limit)

# identifies in what movement state player is currently in
enum MovementStates {IDLE, WALK, RUN, CROUCH, SLIDE, JUMP, DOUBLEJUMP, WALLJUMP}

var movement_state = MovementStates.IDLE

@onready var uncrouch_ray_cast_colliding: bool
@onready var unslide_ray_cast_colliding: bool
func can_player_stand_up() -> void:
	uncrouch_ray_cast_colliding = $CrouchRayCast.is_colliding()
	unslide_ray_cast_colliding = $SlideRayCast.is_colliding()

func get_idle_state() -> bool:
	return movement_directions.z == 0 and movement_directions.x == 0 and is_on_floor() and !uncrouch_ray_cast_colliding

func get_walk_state() -> bool:
	return (movement_directions.z != 0 or movement_directions.x != 0) and is_on_floor() and (movement_state != MovementStates.JUMP or movement_state != MovementStates.DOUBLEJUMP) and !uncrouch_ray_cast_colliding

func get_run_state() -> bool:
	return Input.is_action_pressed("run") and movement_directions.z < 0 and is_on_floor() and !uncrouch_ray_cast_colliding

func get_crouch_state() -> bool:
	return ((Input.is_action_pressed("crouch") and is_on_floor()) and !unslide_ray_cast_colliding) or uncrouch_ray_cast_colliding

func get_slide_state() -> bool:
	return Input.is_action_pressed("slide") and is_on_floor() and movement_directions.z < 0

func get_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and is_on_floor() and movement_state != MovementStates.CROUCH

func get_double_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and !is_on_floor() and can_double_jump and !get_walk_state()

func get_wall_jump_state() -> bool:
	return Input.is_action_just_pressed("jump") and is_on_wall_only() and (movement_directions.z != 0 or movement_directions.x != 0)

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
		change_movement_state(MovementStates.SLIDE)
	elif get_run_state():
		change_movement_state(MovementStates.RUN)
	elif get_crouch_state():
		change_movement_state(MovementStates.CROUCH)
	elif get_walk_state():
		change_movement_state(MovementStates.WALK)
	elif get_idle_state():
		change_movement_state(MovementStates.IDLE)

@export_category("Collision Shape Animations")
var collision_blend_amount: float = 0.0
@export_group("Animation Speed")
@export var crouch_animation_speed: float = 7.5
@export var slide_animation_speed: float = 10.0
@export_group("Animation Blend Amount")
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

var movement_speed: float = 0.0

@export_category("Crouching and Walking")
@export var crouch_speed: float = 1.5
@export var walk_speed: float = 1.5
var current_walk_speed: float = 1.5

@export_category("Running")
var run_speed: float = 0.0
@export var max_run_speed: float = 2.5
@export_group("Speed Icrease and Decrease")
@export var run_speed_increase: float = 0.75
@export var run_walk_decrease: float = 2.5
@export var run_crouch_decrease: float = 4.0

@export_category("Sliding")
var slide_speed: float = 0.0
@export var max_slide_speed: float = 2.5

@export var slide_buff_multiplier: float = 0.15 # multiplies (after adding slope_interference) slide buff from floor_speed
@export var slope_interference_factor: float = 0.85 # how much slope interference will actually work on calculating slide buff

@export_group("Speed Icrease and Decrease")
@export var slide_run_decrease: float = 0.1 # decrease when switching to running
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
	
	var floor_speed = crouch_speed + current_walk_speed + run_speed
	var actual_slide_buff_multiplier = slide_buff_multiplier + slope_interference
	var slide_buff = floor_speed * actual_slide_buff_multiplier
	
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

# in what direction player is trying to move
var movement_directions: Vector3
func get_movement_directions() -> void:
	movement_directions.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	movement_directions.z = Input.get_action_strength("back") - Input.get_action_strength("forward")

@export_category("Gravity")
# applies gravity to player's body, when it's not on floor
@export var gravity_force: float = 18
func gravity(delta) -> void:
	if !is_on_floor():
		movement_directions.y -= gravity_force * delta
	else:
		movement_directions.y = 0

@export_category("Jumping")
# adds jumping mechanic to player's movement
@export var jump_velocity: float = 7.5
func jump() -> void:
	if get_jump_state():
		movement_directions.y += jump_velocity

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
			movement_directions.y = 0
		
		movement_directions.y += jump_velocity * double_jump_multiplier
		can_double_jump = false
		double_jumping = true
		
		reset_wall_jumping_directions()

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
		movement_directions.y = 0
		movement_directions.y += movement_speed * vertical_jump_factor
		
		# direction of wall jump
		if !Input.is_action_pressed("change_wall_jump_direction"): # player wan't to "bounce" from a wall
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * movement_directions)
		else: # player want to jump in same direction he jumped from
			wall_jump_direction = -get_wall_normal().direction_to(-transform.basis.z * -movement_directions)
	
	if is_on_floor():
		reset_wall_jumping_directions()

func movement_velocity() -> void:
	var transform_x: Vector3 = global_transform.basis.x * movement_directions.x
	var transform_y: Vector3 = global_transform.basis.y * movement_directions.y
	var transform_z: Vector3 = global_transform.basis.z * movement_directions.z
	
	if movement_state != MovementStates.WALLJUMP:
		velocity = (transform_x.normalized() + transform_z.normalized()) * movement_speed + transform_y
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
	
	can_player_stand_up()
	
	set_movement_states()
	
	collision_shape_animations(delta)
	
	calculate_movement_speed(delta)
	
	get_movement_directions()
	
	gravity(delta)
	jump()
	double_jump(delta)
	
	wall_jumping()
	
	movement_velocity()
	
	var movement_states_array = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLEJUMP", "WALLJUMP"]
	#%Debug.text = str("Movement Speed: ", snappedf(movement_speed, 0.1), " Movement State: ", movement_states_array[movement_state])
