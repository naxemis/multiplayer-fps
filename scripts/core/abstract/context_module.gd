@abstract class_name ContextModule
extends RefCounted

@abstract class NodeRefs extends RefCounted:
	pass

@abstract class Components extends RefCounted:
	pass

@abstract class Init extends RefCounted:
	pass

@abstract class Process extends RefCounted:
	pass

@abstract class Physics extends RefCounted:
	pass

@abstract func init_node_refs_data(data: ContextData.NodeRefs) -> void

@abstract func init_components_data(data: ContextData.Components) -> void

@abstract func init_init_data(data: ContextData.Init) -> void

@abstract func update_process_data(data: ContextData.Process) -> void

@abstract func update_physics_data(data: ContextData.Physics) -> void