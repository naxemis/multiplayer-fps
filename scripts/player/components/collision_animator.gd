class_name CollisionAnimator
extends Node

# Signals

# Enums and constants

# @export vars
@export_category("Collision Shape Animations")
@export var crouch_animation_speed: float = 7.5
@export var slide_animation_speed: float = 10.0

@export var crouch_blend_amount: float = 1.0
@export var slide_blend_amount: float = 2.0

# Public vars

# Private vars (_)
var _player_context_module: PlayerContextModule
var _state_machine: StateMachine
var _animation_tree: AnimationTree
var _collision_blend_amount: float = 0.0

# @onready vars

# _init / _ready
# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _process(delta: float) -> void:
	_collision_shape_animations(delta)

# Public methods (component APIs)
func pass_player_context_module(player_context: PlayerContextModule) -> void:
	_player_context_module = player_context
	_state_machine = player_context.components.state_machine
	_animation_tree = _player_context_module.node_refs.collision_animation_tree

# Private methods (_)
func _collision_shape_animations(delta) -> void:
	_collision_blend_amount = clampf(_collision_blend_amount, 0.0, slide_blend_amount)
	
	if _state_machine._current_state == _state_machine.MovementStates.CROUCH:
		_collision_blend_amount = lerpf(_collision_blend_amount, crouch_blend_amount, crouch_animation_speed * delta)
	elif _state_machine._current_state == _state_machine.MovementStates.SLIDE:
		_collision_blend_amount = lerpf(_collision_blend_amount, slide_blend_amount, slide_animation_speed * delta)
	else:
		if _collision_blend_amount <= crouch_blend_amount:
			_collision_blend_amount = lerpf(_collision_blend_amount, 0.0, crouch_animation_speed * delta)
		elif _collision_blend_amount > crouch_blend_amount:
			_collision_blend_amount = lerpf(_collision_blend_amount, 0.0, slide_animation_speed * delta)
	
	_animation_tree["parameters/State Blend/blend_amount"] = _collision_blend_amount
