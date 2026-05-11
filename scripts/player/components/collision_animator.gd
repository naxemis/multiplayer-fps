class_name CollisionAnimator
extends Component

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
var _target_blend_amount: float = 0.0
var _target_blend_speed: float = 0.0

# @onready vars

# _init / _ready
# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _process(delta: float) -> void:
	_collision_shape_animations(delta)

# Public methods (component APIs)
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context
	_state_machine = context.components.state_machine
	_animation_tree = _player_context_module.node_refs.collision_animation_tree

	_state_machine.state_changed.connect(_on_state_changed)
	_on_state_changed(_state_machine._current_state)

# Private methods (_)
func _on_state_changed(new_state: int) -> void:
	match new_state:
		_state_machine.MovementStates.CROUCH:
			_target_blend_amount = crouch_blend_amount
			_target_blend_speed = crouch_animation_speed
		_state_machine.MovementStates.SLIDE:
			_target_blend_amount = slide_blend_amount
			_target_blend_speed = slide_animation_speed
		_:
			_target_blend_amount = 0.0
			_target_blend_speed = 0.0 # picked per-frame in _collision_shape_animations based on current blend

func _collision_shape_animations(delta) -> void:
	_collision_blend_amount = clampf(_collision_blend_amount, 0.0, slide_blend_amount)

	var speed: float = _target_blend_speed
	if _target_blend_amount == 0.0:
		speed = crouch_animation_speed if _collision_blend_amount <= crouch_blend_amount else slide_animation_speed

	_collision_blend_amount = lerpf(_collision_blend_amount, _target_blend_amount, speed * delta)
	_animation_tree["parameters/State Blend/blend_amount"] = _collision_blend_amount
