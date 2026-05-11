## Typed payload backing [PlayerContextModule].
##
## [Player] allocates this in [method Player._ready], fills every slot from scene-tree lookups, then hands the inner buckets to the matching [PlayerContextModule].
## Components never read this directly; they go through the module's accessor wrappers.
class_name PlayerContextData
extends ContextData

## Concrete bucket of scene-tree node references owned by [Player].
class NodeRefs extends ContextData.NodeRefs:
	## Root [Player] [CharacterBody3D].
	var player: Player
	## Head pivot rotated by [CameraController] for look pitch and free-look.
	var head: Node3D
	## Active [Camera3D] mounted under the head pivot.
	var camera: Camera3D
	## HUD stamina bar written by [StaminaManager].
	var stamina_bar: TextureProgressBar
	## [AnimationTree] driving the player's collision-shape morph.
	var collision_animation_tree: AnimationTree

## Concrete bucket of sibling component references owned by [Player].
class Components extends ContextData.Components:
	## Camera/head input + FOV controller.
	var camera_controller: CameraController
	## Movement state selector.
	var state_machine: StateMachine
	## Per-tick velocity producer and jump API holder.
	var movement_controller: MovementController
	## Stamina drain/recovery + gating.
	var stamina_manager: StaminaManager
	## Collision-shape blend animator.
	var collision_animator: CollisionAnimator

## Inner [NodeRefs] payload; written by [Player] before being passed to the [PlayerContextModule].
var node_refs: NodeRefs
## Inner [Components] payload; written by [Player] before being passed to the [PlayerContextModule].
var components: Components

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()
