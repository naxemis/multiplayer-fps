class_name PlayerContextData
extends ContextData

class NodeRefs extends ContextData.NodeRefs:
	var player: Player
	var head: Node3D
	var camera: Camera3D

class Components extends ContextData.Components:
	var camera_controller: CameraController
	var state_machine: StateMachine
	var movement_controller: MovementController

var node_refs: NodeRefs
var components: Components

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()
