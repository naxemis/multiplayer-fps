## Read-only [ContextModule] specialization exposing every node reference and sibling [Component] needed by player subsystems.
##
## Constructed once by [Player] in [method Player._ready] and injected into every component via [method Component.pass_context_module].
## Components read dependencies through [member node_refs] and [member components] rather than holding direct references to the player or to each other, which keeps each component pluggable and avoids circular references between subsystems.
class_name PlayerContextModule
extends ContextModule

# TODO (EXTRACTING VALUES TO PLAYER CONTEXT MODULE) [IN PROGRESS]:
# In context add a link to certain components (f.e. instead of "var stamin: float" do "var stamina: StaminaComponent")
# and then in the state machine we can call stamina.consume(amount) or something like that.
# This way we can avoid having to pass the whole player reference to the context
# and also avoid having to have a reference to the state machine in the stamina component (which would create a circular reference).

## Typed read-only view over [member PlayerContextData.NodeRefs].
## Each property proxies to the underlying [code]data[/code] field set by [Player] before the module is handed to components.
class NodeRefs extends ContextModule.NodeRefs:
	## Root [Player] [CharacterBody3D].
	## Used for transforms, floor/wall queries and global velocity.
	var player: Player:
		get: return data.player
	## Pivot node carrying the camera.
	## Rotated by [CameraController] to apply look pitch and free-look offsets independently of the body yaw.
	var head: Node3D:
		get: return data.head
	## Active [Camera3D] mounted on the head pivot.
	## [CameraController] writes its FOV per frame from the current movement speed.
	var camera: Camera3D:
		get: return data.camera
	## HUD stamina bar.
	## [StaminaManager] writes [code]value[/code], [code]max_value[/code] and tints it red when stamina drops into the safe-zone threshold.
	var stamina_bar: TextureProgressBar:
		get: return data.stamina_bar
	## [AnimationTree] driving the player's [CollisionShape3D] morph between stand / crouch / slide poses.
	## [CollisionAnimator] writes its [code]parameters/State Blend/blend_amount[/code] each frame.
	var collision_animation_tree: AnimationTree:
		get: return data.collision_animation_tree

## Typed read-only view over [member PlayerContextData.Components].
## Components fetch their siblings through these properties so wiring stays declarative and the [Player] owns the only mutable references.
class Components extends ContextModule.Components:
	## Centralized [Input] adapter.
	## Other components read action state through this rather than calling [Input] directly, and subscribe to [signal InputHandler.mouse_motion] for per-frame mouse delta.
	var input_handler: InputHandler:
		get: return data.input_handler
	## Handles look input, head pitch/yaw, free-look and FOV interpolation.
	var camera_controller: CameraController:
		get: return data.camera_controller
	## Selects the current [enum StateMachine.MovementStates] each physics tick.
	var state_machine: StateMachine:
		get: return data.state_machine
	## Computes per-tick velocity and exposes jump/double-jump/wall-jump APIs.
	var movement_controller: MovementController:
		get: return data.movement_controller
	## Tracks stamina drain/recovery and gates stamina-bound actions.
	var stamina_manager: StaminaManager:
		get: return data.stamina_manager
	## Animates the player's collision shape between stand, crouch and slide.
	var collision_animator: CollisionAnimator:
		get: return data.collision_animator

## Accessor for scene-tree node references; populated by [method init_node_refs_data].
var node_refs: NodeRefs
## Accessor for sibling components; populated by [method init_components_data].
var components: Components

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()

## Stores the filled [PlayerContextData.NodeRefs] payload behind the [member node_refs] accessor.
func init_node_refs_data(data: ContextData.NodeRefs) -> void:
	node_refs.data = data

## Stores the filled [PlayerContextData.Components] payload behind the [member components] accessor.
func init_components_data(data: ContextData.Components) -> void:
	components.data = data
