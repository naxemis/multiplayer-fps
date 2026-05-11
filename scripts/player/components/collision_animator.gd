## Drives the player's collision-shape morph between stand, crouch and slide poses by writing into the [AnimationTree]'s blend parameter each frame.
##
## Listens to [signal StateMachine.state_changed] to pick a target blend amount and ease speed; on every [method _process] tick the current blend value lerps toward that target.
## The state-blend parameter path written is [code]parameters/State Blend/blend_amount[/code], expecting an [AnimationNodeBlendTree] with three poses crossfaded by a scalar.
class_name CollisionAnimator
extends Component

# Signals

# Enums and constants

# @export vars
@export_category("Collision Shape Animations")
## Lerp rate (per second) applied while easing toward the crouch blend value.
## Higher values produce a snappier crouch.
@export var crouch_animation_speed: float = 7.5
## Lerp rate (per second) applied while easing toward the slide blend value.
## Higher values produce a snappier slide.
@export var slide_animation_speed: float = 10.0

## Target value for the AnimationTree blend parameter while the [enum StateMachine.MovementStates] is [code]CROUCH[/code].
## Convention: crouch sits at 1.0 on the [0, slide_blend_amount] scale.
@export var crouch_blend_amount: float = 1.0
## Target value for the AnimationTree blend parameter while the [enum StateMachine.MovementStates] is [code]SLIDE[/code].
## Acts as the upper bound of the blend clamp.
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
## Caches the [StateMachine] and [AnimationTree] from the context, connects to [signal StateMachine.state_changed], and primes the target from the current state so the shape starts in the correct pose without an initial pop.
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
