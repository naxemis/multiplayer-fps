class_name PlayerContextModule
extends ContextModule

# TODO (EXTRACTING VALUES TO PLAYER CONTEXT MODULE) [IN PROGRESS]: 
# In context add a link to certain components (f.e. instead of "var stamin: float" do "var stamina: StaminaComponent")
# and then in the state machine we can call stamina.consume(amount) or something like that.
# This way we can avoid having to pass the whole player reference to the context
# and also avoid having to have a reference to the state machine in the stamina component (which would create a circular reference).

class NodeRefs extends ContextModule.NodeRefs:
	var player: Player: 
		get: return data.player
	var head: Node3D:
		get: return data.head
	var camera: Camera3D:
		get: return data.camera

class Components extends ContextModule.Components:
	var camera_controller: CameraController:
		get: return data.camera_controller
	var state_machine: MovementStateMachine:
		get: return data.state_machine
	var movement_controller: MovementController:
		get: return data.movement_controller

class Init extends ContextModule.Init:
	var stamina_safe_zone: float:
		get: return data.stamina_safe_zone
	var jump_stamina_drain: float:
		get: return data.jump_stamina_drain
	var double_jump_stamina_drain: float:
		get: return data.double_jump_stamina_drain
	var wall_jump_stamina_drain: float:
		get: return data.wall_jump_stamina_drain
	
class Physics extends ContextModule.Physics:
	var is_on_floor: bool:
		get: return data.is_on_floor
	var is_on_wall: bool:
		get: return data.is_on_wall
	var is_on_wall_only: bool:
		get: return data.is_on_wall_only
	var velocity: Vector3:
		get: return data.velocity
	var movement_directions: Vector3:
		get: return data.movement_directions
	var stamina: float:
		get: return data.stamina
	var floor_normal: Vector3:
		get: return data.floor_normal
	var forward_vector: Vector3:
		get: return data.forward_vector

var node_refs: NodeRefs
var components: Components
var init: Init
var physics: Physics

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()
	init = Init.new()
	physics = Physics.new()
	
func init_node_refs_data(data: ContextData.NodeRefs) -> void:
	node_refs.data = data

func init_components_data(data: ContextData.Components) -> void:
	components.data = data
	
func init_init_data(data: ContextData.Init) -> void:	
	init.data = data

func update_process_data(data: ContextData.Process) -> void:
	assert(false, "No process data for player context module. Don't use update_process_data!")

func update_physics_data(data: ContextData.Physics) -> void:
	physics.data = data