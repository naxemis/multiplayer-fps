# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Central adapter over the global [Input] singleton and the [InputEvent] stream.
##
## Player components read movement, look and action state through this component instead of touching [Input] directly, which keeps action names and event routing in exactly one place.
## Mouse motion arrives only as [InputEventMouseMotion] (it cannot be polled), so [method handle_input] re-emits [signal mouse_motion] for subscribers.
## All other action state is exposed as lazy accessor properties (e.g. [member run_held], [member movement_axis]) that read [Input] on demand, so there is no per-tick cache to keep in sync.
class_name InputHandler
extends Component

# Signals
## Emitted from [method handle_input] for each [InputEventMouseMotion].
## Subscribers (e.g. [CameraController]) read [code]relative[/code] in pixels of motion this frame.
signal mouse_motion(relative: Vector2)
## Emitted on the frame the [code]free_look[/code] action is pressed.
signal freelook_started
## Emitted on the frame the [code]free_look[/code] action is released.
signal freelook_stopped

# Enums and constants
const _ACTION_MOVE_RIGHT: StringName = &"right"
const _ACTION_MOVE_LEFT: StringName = &"left"
const _ACTION_MOVE_FORWARD: StringName = &"forward"
const _ACTION_MOVE_BACK: StringName = &"back"
const _ACTION_JUMP: StringName = &"jump"
const _ACTION_RUN: StringName = &"run"
const _ACTION_CROUCH: StringName = &"crouch"
const _ACTION_SLIDE: StringName = &"slide"
const _ACTION_FREE_LOOK: StringName = &"free_look"
const _ACTION_CHANGE_WALL_JUMP_DIRECTION: StringName = &"change_wall_jump_direction"

# @export vars

# Public vars
## Planar movement axis derived from the four directional actions.
## [code]x[/code] is right-minus-left.
## [code]y[/code] is back-minus-forward, kept Z-positive-backward to match [member MovementController._movement_directions]'s convention.
var movement_axis: Vector3:
	get: return Vector3(
		Input.get_action_strength(_ACTION_MOVE_RIGHT) - Input.get_action_strength(_ACTION_MOVE_LEFT),
		0, 
		Input.get_action_strength(_ACTION_MOVE_BACK) - Input.get_action_strength(_ACTION_MOVE_FORWARD)
	)

## True while the [code]run[/code] action is held.
var run_held: bool:
	get: return Input.is_action_pressed(_ACTION_RUN)

## True while the [code]crouch[/code] action is held.
var crouch_held: bool:
	get: return Input.is_action_pressed(_ACTION_CROUCH)

## True while the [code]slide[/code] action is held.
var slide_held: bool:
	get: return Input.is_action_pressed(_ACTION_SLIDE)

## True while the [code]free_look[/code] action is held.
var freelook_held: bool:
	get: return Input.is_action_pressed(_ACTION_FREE_LOOK)

## True while the [code]change_wall_jump_direction[/code] action is held.
var change_wall_jump_dir_held: bool:
	get: return Input.is_action_pressed(_ACTION_CHANGE_WALL_JUMP_DIRECTION)

## True only on the frame the [code]jump[/code] action transitions from released to pressed.
## Stable across multiple reads in the same frame, so several [StateMachine] entry guards may all consult it.
var jump_just_pressed: bool:
	get: return Input.is_action_just_pressed(_ACTION_JUMP)

# Private vars (_)
var _player_context_module: PlayerContextModule

# @onready vars

# _init / _ready
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)

# Public methods (component APIs)
## Caches the injected context module.
## No sibling references are held; consumers reach this component through [member PlayerContextModule.components.input_handler] and either connect to its signals or read its action-state properties.
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context

## Routes a raw [InputEvent] from [method Player._unhandled_input].
## Mouse motion is re-broadcast through [signal mouse_motion].
## The [code]free_look[/code] action edge is surfaced as [signal freelook_started] / [signal freelook_stopped].
## Other actions are intentionally not signalled here — read [member run_held], [member jump_just_pressed], etc. instead.
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_motion.emit((event as InputEventMouseMotion).relative)

	if event.is_action_pressed(_ACTION_FREE_LOOK):
		freelook_started.emit()
	elif event.is_action_released(_ACTION_FREE_LOOK):
		freelook_stopped.emit()

# Private methods (_)
