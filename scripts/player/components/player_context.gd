class_name PlayerContext
extends RefCounted

# TODO: In context add that gives a link to certain components (f.e. instead of stamin: float do stamina: StaminaComponent)
# TODO: and then in the state machine we can call stamina.consume(amount) or something like that.
# TODO: This way we can avoid having to pass the whole player reference to the context
# TODO: and also avoid having to have a reference to the state machine in the stamina component (which would create a circular reference).

# Scene node references
var head: Node3D 
var camera: Camera3D

# Component references
var camera_controller: CameraController
var state_machine: MovementStateMachine

# Static variables
var walk_speed: float
var crouch_speed: float
var stamina_safe_zone: float
var jump_stamina_drain: float
var double_jump_stamina_drain: float
var wall_jump_stamina_drain: float

# Process variables
var body_rotation: Vector3

# Physics process variables
var on_floor: bool
var on_wall_only: bool
var velocity: Vector3
var movement_directions: Vector3
var movement_speed: float
var velocity_timeout: bool
var stamina: float
