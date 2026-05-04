@abstract class_name ContextModule
extends RefCounted

class NodeRefs extends RefCounted:
	var data

class Components extends RefCounted:
	var data

class Init extends RefCounted:
	var data

class Process extends RefCounted:
	var data

class Physics extends RefCounted:
	var data

@abstract func _init() -> void

@abstract func init_node_refs_data(data: ContextData.NodeRefs) -> void

@abstract func init_components_data(data: ContextData.Components) -> void

@abstract func init_init_data(data: ContextData.Init) -> void

@abstract func update_process_data(data: ContextData.Process) -> void

@abstract func update_physics_data(data: ContextData.Physics) -> void