## Abstract base for any [Node] subsystem composed into a host entity through a [ContextModule].
##
## A concrete component encapsulates one slice of behavior (input handling, state selection, animation driving, etc.) and reads its dependencies — host node, sibling components, scene references — from a [ContextModule] built by the host.
## Each component receives the module exactly once via [method pass_context_module] after the scene tree is ready, then runs its own engine callbacks ([code]_process[/code], [code]_physics_process[/code], etc.) independently.
## The base imposes no domain assumptions, so the same pattern works for any composite entity (players, enemies, vehicles, UI controllers, etc.).
@abstract class_name Component
extends Node

# Signals

# Enums and constants

# @export vars

# Public vars

# Private vars (_)

# @onready vars

# _init / _ready

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)

# Public methods (component APIs)
## Dependency-injection entry point.
## Called once by the host entity after its [ContextModule] is fully populated with node references and sibling components.
## Implementations cache the references they need and may connect to signals on sibling components from here.
## Must not be called more than once.
@abstract func pass_context_module(context: ContextModule) -> void

# Private methods (_)
