class_name PlayerContextData
extends ContextData

class NodeRefs extends ContextData.NodeRefs:
	var player: Player
	var head: Node3D 
	var camera: Camera3D

class Components extends ContextData.Components:
	var camera_controller: CameraController
	var state_machine: MovementStateMachine
	var movement_controller: MovementController

class Init extends ContextData.Init:
	var stamina_safe_zone: float
	var jump_stamina_drain: float
	var double_jump_stamina_drain: float
	var wall_jump_stamina_drain: float

class Process extends ContextData.Process:
	pass

class Physics extends ContextData.Physics:
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
var init: Init
var physics: Physics

func _init() -> void:
	node_refs = NodeRefs.new()
	components = Components.new()
	init = Init.new()
	physics = Physics.new()