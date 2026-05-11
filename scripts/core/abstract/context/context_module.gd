# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Abstract read-only wrapper around a [ContextData] payload.
##
## A [ContextModule] exposes the typed slots stored in [ContextData] through nested [NodeRefs] and [Components] accessor classes.
## The host entity constructs a concrete [ContextData], fills its slots, then passes the two sub-objects in via [method init_node_refs_data] and [method init_components_data].
## [Component]s receive the module via [method Component.pass_context_module] and read dependencies through it without touching the raw data object.
@abstract class_name ContextModule
extends RefCounted

## Read-only accessor wrapper around [member ContextData.NodeRefs].
## Subclasses add typed getters that proxy to fields on the held [code]data[/code] object.
class NodeRefs extends RefCounted:
	var data

## Read-only accessor wrapper around [member ContextData.Components].
## Subclasses add typed getters that proxy to fields on the held [code]data[/code] object.
class Components extends RefCounted:
	var data

@abstract func _init() -> void

## Stores the [ContextData.NodeRefs] payload on the [NodeRefs] accessor.
## Called by the host entity after every node-reference slot is filled.
@abstract func init_node_refs_data(data: ContextData.NodeRefs) -> void

## Stores the [ContextData.Components] payload on the [Components] accessor.
## Called by the host entity after every component slot is filled.
@abstract func init_components_data(data: ContextData.Components) -> void
