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
	var stamina_bar: TextureProgressBar:
		get: return data.stamina_bar
	var collision_animation_tree: AnimationTree:
		get: return data.collision_animation_tree

class Components extends ContextModule.Components:
	var camera_controller: CameraController:
		get: return data.camera_controller
	var state_machine: StateMachine:
		get: return data.state_machine
	var movement_controller: MovementController:
		get: return data.movement_controller
	var stamina_manager: StaminaManager:
		get: return data.stamina_manager
	var collision_animator: CollisionAnimator:
		get: return data.collision_animator

var node_refs: NodeRefs
var components: Components

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()

func init_node_refs_data(data: ContextData.NodeRefs) -> void:
	node_refs.data = data

func init_components_data(data: ContextData.Components) -> void:
	components.data = data
