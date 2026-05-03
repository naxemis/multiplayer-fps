@abstract class_name ContextModule
extends RefCounted

@abstract class NodeRefs extends RefCounted:
	pass

@abstract class Components extends RefCounted:
	pass

@abstract class InitData extends RefCounted:
	pass

@abstract class ProcessData extends RefCounted:
	pass

@abstract class PhysicsData extends RefCounted:
	pass

@abstract func init_node_refs(data: ContextData) -> void

@abstract func init_components(data: ContextData) -> void

@abstract func init_init_data(data: ContextData) -> void

@abstract func update_process_data(data: ContextData) -> void

@abstract func update_physics_data(data: ContextData) -> void

static func assert_same_fields(data_class: GDScript, target_class: GDScript) -> void:
	var data_fields := _collect_fields_from_script(data_class)
	var target_fields := _collect_fields_from_script(target_class)
	
	var missing := target_fields.keys().filter(func(k): return not data_fields.has(k))
	var extra := data_fields.keys().filter(func(k): return not target_fields.has(k))
	
	assert(missing.is_empty(),"%s missing fields present in %s: %s" % [data_class, target_class, str(missing)])
	assert(extra.is_empty(),"%s has extra fields not present in %s: %s" % [data_class, target_class, str(extra)])

static func _collect_fields_from_script(script: GDScript) -> Dictionary:
	var result := {}
	for prop in script.get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[prop.name] = prop.type
	return result