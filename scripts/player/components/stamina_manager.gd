## Tracks the player's stamina pool and gates stamina-bound actions.
##
## Recovery and drain rates are expressed in stamina/second.
## The active rate is selected by [signal StateMachine.state_changed]: idle/crouch/walk/run states regenerate at their named rates, [code]SLIDE[/code] drains at [member slide_stamina_drain], and airborne states regenerate at the slow [member in_air_stamina_recovery] rate.
## Jump variants spend their own one-shot drains via [method drain_once].
## The [TextureProgressBar] HUD widget is driven directly each physics tick.
class_name StaminaManager
extends Component

# Signals

# Enums and constants

# @export vars
@export_category("Movement Stamina")
## Maximum stamina pool size in stamina-units.
## Both the bar and [method reset] clamp to this value.
@export var max_stamina: float = 100.0
## Current stamina value.
## Initialized to [member max_stamina] when the node is ready, mutated by per-state recovery and one-shot drains.
@onready var stamina: float = max_stamina

## Recovery rate (stamina/sec) while in [code]IDLE[/code].
@export var idle_stamina_recovery: float = 25.0
## Recovery rate (stamina/sec) while in [code]CROUCH[/code].
@export var crouch_stamina_recovery: float = 17.5
## Recovery rate (stamina/sec) while in [code]WALK[/code].
@export var walk_stamina_recovery: float = 12.5
## Recovery rate (stamina/sec) while in [code]RUN[/code].
@export var run_stamina_recovery: float = 7.5
## Recovery rate (stamina/sec) while in any airborne state ([code]JUMP[/code], [code]DOUBLE_JUMP[/code], [code]WALL_JUMP[/code], [code]FALL[/code]).
@export var in_air_stamina_recovery: float = 2.5

## Drain rate (stamina/sec) applied while in [code]SLIDE[/code].
## Stored as a positive value; the rate-table flips its sign.
@export var slide_stamina_drain: float = 7.5

## One-shot cost subtracted on every ground jump.
@export var jump_stamina_drain: float = 5.0
## One-shot cost subtracted on every double jump.
@export var double_jump_stamina_drain: float = 2.5
## One-shot cost subtracted on every wall jump.
@export var wall_jump_stamina_drain: float = 2.5

## Threshold under which stamina is considered "tapped out": the bar turns red, [method is_above_safe_zone] returns false, and [method can_perform] refuses to spend.
@export var stamina_safe_zone: float = 10.0

# Public vars

# Private vars (_)
var _player_context_module: PlayerContextModule
var _player: Player
var _state_machine: StateMachine
var _stamina_bar: TextureProgressBar
var _current_recovery_rate: float = 0.0

# @onready vars

# _init / _ready

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _physics_process(delta: float) -> void:
	_calculate_stamina(delta)

# Public methods (component APIs)
## Caches sibling components and HUD nodes, connects to [signal StateMachine.state_changed], and primes the recovery rate from the current state.
func pass_context_module(context: ContextModule) -> void:
	_player_context_module = context
	_player = context.node_refs.player
	_state_machine = context.components.state_machine
	_stamina_bar = context.node_refs.stamina_bar

	_state_machine.state_changed.connect(_on_state_changed)
	_current_recovery_rate = _rate_for_state(_state_machine._current_state)

## Subtracts [code]value_of_stamina_drain[/code] from the pool once.
## Called by [MovementController] for jump variants.
func drain_once(value_of_stamina_drain: float) -> void:
	stamina -= value_of_stamina_drain

## True if current stamina is strictly above [member stamina_safe_zone].
## Used by [StateMachine] to gate slide entry.
func is_above_safe_zone() -> bool:
	return stamina > stamina_safe_zone

## True if [member stamina] is above [code]minimum[/code] (defaults to zero).
func has_stamina(minimum: float = 0.0) -> bool:
	return stamina > minimum

## True if the pool is above [member stamina_safe_zone] *and* spending [code]cost[/code] would leave it positive.
## Used to gate jumps.
func can_perform(cost: float) -> bool:
	return stamina > stamina_safe_zone and stamina - cost > 0

## Restores [member stamina] to [member max_stamina].
func reset() -> void:
	stamina = max_stamina

# Private methods (_)
func _on_state_changed(new_state: int) -> void:
	_current_recovery_rate = _rate_for_state(new_state)

func _rate_for_state(state: int) -> float:
	match state:
		_state_machine.MovementStates.IDLE: return idle_stamina_recovery
		_state_machine.MovementStates.CROUCH: return crouch_stamina_recovery
		_state_machine.MovementStates.WALK: return walk_stamina_recovery
		_state_machine.MovementStates.RUN: return run_stamina_recovery
		_state_machine.MovementStates.SLIDE: return -slide_stamina_drain
		_state_machine.MovementStates.JUMP, \
		_state_machine.MovementStates.DOUBLE_JUMP, \
		_state_machine.MovementStates.WALL_JUMP, \
		_state_machine.MovementStates.FALL:
			return in_air_stamina_recovery
	return 0.0

func _calculate_stamina(delta: float) -> void:
	stamina = clampf(stamina + _current_recovery_rate * delta, 0.0, max_stamina)

	if stamina <= stamina_safe_zone:
		_stamina_bar.tint_progress = Color(188, 0, 0)
	else:
		_stamina_bar.tint_progress = Color(255, 255, 255)

	_stamina_bar.value = stamina
	_stamina_bar.max_value = max_stamina
