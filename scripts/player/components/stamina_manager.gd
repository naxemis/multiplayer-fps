class_name StaminaManager
extends Node

# Signals

# Enums and constants

# @export vars
@export_category("Movement Stamina")
@export var max_stamina: float = 100.0
@onready var stamina: float = max_stamina

@export var idle_stamina_recovery: float = 25.0
@export var crouch_stamina_recovery: float = 17.5
@export var walk_stamina_recovery: float = 12.5
@export var run_stamina_recovery: float = 7.5
@export var in_air_stamina_recovery: float = 2.5

@export var slide_stamina_drain: float = 7.5

@export var jump_stamina_drain: float = 5.0
@export var double_jump_stamina_drain: float = 2.5
@export var wall_jump_stamina_drain: float = 2.5

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
func pass_player_context_module(player_context: PlayerContextModule) -> void:
	_player_context_module = player_context
	_player = player_context.node_refs.player
	_state_machine = player_context.components.state_machine
	_stamina_bar = player_context.node_refs.stamina_bar

	_state_machine.state_changed.connect(_on_state_changed)
	_current_recovery_rate = _rate_for_state(_state_machine._current_state)

func drain_once(value_of_stamina_drain: float) -> void:
	stamina -= value_of_stamina_drain

func is_above_safe_zone() -> bool:
	return stamina > stamina_safe_zone

func has_stamina(minimum: float = 0.0) -> bool:
	return stamina > minimum

func can_perform(cost: float) -> bool:
	return stamina > stamina_safe_zone and stamina - cost > 0

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
