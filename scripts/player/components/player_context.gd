class_name PlayerContext
extends RefCounted

# TODO: Create abstract class of "Context" that will be a blueprint for all contexts in the game

# TODO (Extracting values to PlayerContext): 
# In context add a link to certain components (f.e. instead of "var stamin: float" do "var stamina: StaminaComponent")
# and then in the state machine we can call stamina.consume(amount) or something like that.
# This way we can avoid having to pass the whole player reference to the context
# and also avoid having to have a reference to the state machine in the stamina component (which would create a circular reference).

# Scene node references
var head: Node3D 
var camera: Camera3D

# Component references
var camera_controller: CameraController
var state_machine: MovementStateMachine
var movement_controller: MovementController

# Static variables
var stamina_safe_zone: float
var jump_stamina_drain: float
var double_jump_stamina_drain: float
var wall_jump_stamina_drain: float

# Process variables
var body_rotation: Vector3

# Physics process variables
var is_on_floor: bool
var is_on_wall: bool
var is_on_wall_only: bool
var velocity: Vector3
var movement_directions: Vector3
var stamina: float
var floor_normal: Vector3
var forward_vector: Vector3
