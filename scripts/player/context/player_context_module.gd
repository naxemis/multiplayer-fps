class_name PlayerContextModule
extends ContextModule

# TODO (Extracting values to PlayerContextModule): 
# In context add a link to certain components (f.e. instead of "var stamin: float" do "var stamina: StaminaComponent")
# and then in the state machine we can call stamina.consume(amount) or something like that.
# This way we can avoid having to pass the whole player reference to the context
# and also avoid having to have a reference to the state machine in the stamina component (which would create a circular reference).

class NodeRefs extends ContextModule.NodeRefs:
	var player: Player
	var head: Node3D 
	var camera: Camera3D

class Components extends ContextModule.Components:
	var camera_controller: CameraController
	var state_machine: MovementStateMachine
	var movement_controller: MovementController

class InitData extends ContextModule.InitData:
	var stamina_safe_zone: float
	var jump_stamina_drain: float
	var double_jump_stamina_drain: float
	var wall_jump_stamina_drain: float
	
class ProcessData extends ContextModule.ProcessData:
	pass
	
class PhysicsData extends ContextModule.PhysicsData:
	var is_on_floor: bool
	var is_on_wall: bool
	var is_on_wall_only: bool
	var velocity: Vector3
	var movement_directions: Vector3
	var stamina: float
	var floor_normal: Vector3
	var forward_vector: Vector3

var node_refs: NodeRefs
var components: Components
var init_data: InitData
var physics_data: PhysicsData

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()
	init_data = InitData.new()
	physics_data = PhysicsData.new()
	
	_assert_same_fields()

func init_node_refs(data: ContextData) -> void:
	data = data as PlayerNodeRefsContextData
	
	node_refs.player = data.player
	node_refs.head = data.head
	node_refs.camera = data.camera

func init_components(data: ContextData) -> void:
	data = data as PlayerComponentsContextData
	
	components.camera_controller = data.camera_controller
	components.state_machine = data.state_machine
	components.movement_controller = data.movement_controller
	
func init_init_data(data: ContextData) -> void:	
	data = data as PlayerInitContextData
	
	init_data.stamina_safe_zone = data.stamina_safe_zone
	init_data.jump_stamina_drain = data.jump_stamina_drain
	init_data.double_jump_stamina_drain = data.double_jump_stamina_drain
	init_data.wall_jump_stamina_drain = data.wall_jump_stamina_drain

func update_process_data(data: ContextData) -> void:
	assert(false, "No process data for player context module. Don't use update_process_data!")

func update_physics_data(data: ContextData) -> void:
	data = data as PlayerPhysicsContextData
	
	physics_data.is_on_floor = data.is_on_floor
	physics_data.is_on_wall = data.is_on_wall
	physics_data.is_on_wall_only = data.is_on_wall_only
	physics_data.velocity = data.velocity
	physics_data.movement_directions = data.movement_directions
	physics_data.stamina = data.stamina
	physics_data.floor_normal = data.floor_normal
	physics_data.forward_vector = data.forward_vector

func _assert_same_fields() -> void:
	ContextModule.assert_same_fields(PlayerNodeRefsContextData, NodeRefs)
	ContextModule.assert_same_fields(PlayerComponentsContextData, Components)
	ContextModule.assert_same_fields(PlayerInitContextData, InitData)
	ContextModule.assert_same_fields(PlayerPhysicsContextData, PhysicsData)