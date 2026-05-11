# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

@abstract class_name ContextModule
extends RefCounted

class NodeRefs extends RefCounted:
	var data

class Components extends RefCounted:
	var data

@abstract func _init() -> void

@abstract func init_node_refs_data(data: ContextData.NodeRefs) -> void

@abstract func init_components_data(data: ContextData.Components) -> void
