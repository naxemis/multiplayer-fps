class_name ClassName
extends Node

# Signals
signal something_happened(value: int)

# Enums and constants
enum State { IDLE, ACTIVE }
const MAX_THINGS: int = 10

# @export vars
@export_category("Export Category")
@export var parameter: float = 1.0

# Public vars
var current_state: int = State.IDLE

# Private vars (_)
var _internal_counter: int = 0

# @onready vars
@onready var _child: Node = $Child

# _init / _ready
func _init() -> void:
	pass

func _ready() -> void:
	pass

# Engine callbacks (_process, _physics_process, _input, _unhandled_input, etc.)
func _process(delta: float) -> void:
	pass

# Public methods (component APIs)
func public_method() -> void:
	_private_method()

# Private methods (_)
func _private_method() -> void:
	pass
