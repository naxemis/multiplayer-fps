# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Abstract typed payload holding raw references for a [ContextModule].
##
## A [ContextData] is split into two inner buckets:
## [br]- [NodeRefs] for scene-tree nodes that components need (host root, cameras, UI widgets, animation trees, etc.).
## [br]- [Components] for sibling [Component] instances that other components must reach.
##
## Subclasses declare typed [code]var[/code] slots inside these inner classes; the host entity fills them in [method _ready] and then hands the buckets to a matching [ContextModule].
@abstract class_name ContextData
extends RefCounted

## Bucket of scene-tree node references.
## Subclasses add typed fields per node.
class NodeRefs extends RefCounted:
	pass

## Bucket of sibling [Component] references.
## Subclasses add typed fields per component.
class Components extends RefCounted:
	pass

@abstract func _init() -> void
