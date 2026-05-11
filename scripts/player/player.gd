# Copyright (c) 2026 naxemis.
# Licensed under the PolyForm Noncommercial License 1.0.
# Contact: contact@naxemis.dev

## Player root: orchestrates per-tick movement by composing dedicated [Component] subsystems through a [PlayerContextModule].
##
## On [method _ready] this node builds a [PlayerContextData] from its scene children (head, camera, stamina bar, animation tree, attached components), hands it to a [PlayerContextModule] and injects that module into every component via [method Component.pass_context_module].
## The orchestrator itself owns very little state — it routes input to [CameraController], listens for [signal StateMachine.state_changed] to swap [member current_movement_logic], runs the active per-tick movement closure each physics frame, and finally consumes [method MovementController.compute_movement_velocity] to drive [method CharacterBody3D.move_and_slide].
class_name Player
extends CharacterBody3D

# TODO (REFACTOR PLAN) [IN PROGRESS]:
# TODO: Refactor the code by splitting it into multiple scripts and using composition instead of having everything in one script;
# TODO: For example, create separate scripts for handling movement states, stamina, collision shape animations, etc.
# TODO: Then have the Player script use those components to manage the player's behavior.
# TODO: This will make the code more organized, easier to read, and maintainable in the long run.
#
# https://github.com/naxemis/multiplayer-fps/issues/1

# TODO (MOVING UP SLOPES BUG):
# TODO: Movement on slopes is still bugged. Slopes can randomly block players - especially when they are trying to run or slide up them.
# TODO: This is probably because of the way the movement speed is calculated and how it interacts with the slope.
# TODO: The problem presists even on small slopes, so it is not a problem of the player being blocked by the slope itself.
# TODO: Fix the problem when extracting code to seperate scripts, because it' not clear how to do it without breaking the code even more.

## Per-tick movement-logic closure swapped on state change.
## Points at one of [method MovementController._walk] / [code]_run[/code] / [code]_slide[/code] / [code]_crouch_or_other[/code] so [method _physics_process] only calls one function regardless of the active state.
var current_movement_logic: Callable

func _on_state_changed(new_state):
	var states := _state_machine.MovementStates

	match new_state:
		states.IDLE, states.CROUCH: current_movement_logic = _movement_controller._crouch_or_other
		states.WALK: current_movement_logic = _movement_controller._walk
		states.RUN: current_movement_logic = _movement_controller._run
		states.SLIDE: current_movement_logic = _movement_controller._slide
		states.JUMP: _movement_controller.jump()
		states.DOUBLE_JUMP: _movement_controller.double_jump()
		states.WALL_JUMP: _movement_controller.wall_jump()

var _player_context_module: PlayerContextModule = PlayerContextModule.new()
var _state_machine: StateMachine
var _movement_controller: MovementController
var _camera_controller: CameraController
var _stamina_manager: StaminaManager
var _collision_animator: CollisionAnimator

func _unhandled_input(event: InputEvent) -> void:
	_camera_controller.handle_input(event)

var _player_context_data: PlayerContextData

func _create_context_data() -> void:
	_player_context_data = PlayerContextData.new()


func _init_player_node_refs_context_data() -> void:
	_player_context_data.node_refs.player = self
	_player_context_data.node_refs.head = $Head
	_player_context_data.node_refs.camera = %Camera
	_player_context_data.node_refs.stamina_bar = $StaminaBar
	_player_context_data.node_refs.collision_animation_tree = $CollisionAnimationTree

	_player_context_module.init_node_refs_data(_player_context_data.node_refs)

func _init_player_components_context_data() -> void:
	_player_context_data.components.camera_controller = $CameraController
	_player_context_data.components.state_machine = $StateMachine
	_player_context_data.components.movement_controller = $MovementController
	_player_context_data.components.stamina_manager = $StaminaManager
	_player_context_data.components.collision_animator = $CollisionAnimator

	_player_context_module.init_components_data(_player_context_data.components)

func _pass_context_module_to_components() -> void:
	_player_context_module.components.camera_controller.pass_context_module(_player_context_module)
	_player_context_module.components.state_machine.pass_context_module(_player_context_module)
	_player_context_module.components.movement_controller.pass_context_module(_player_context_module)
	_player_context_module.components.stamina_manager.pass_context_module(_player_context_module)
	_player_context_module.components.collision_animator.pass_context_module(_player_context_module)

	_camera_controller = _player_context_module.components.camera_controller
	_state_machine = _player_context_module.components.state_machine
	_movement_controller = _player_context_module.components.movement_controller
	_stamina_manager = _player_context_module.components.stamina_manager
	_collision_animator = _player_context_module.components.collision_animator

func _build_player_context_data() -> void:
	_create_context_data()
	_init_player_node_refs_context_data()
	_init_player_components_context_data()
	_pass_context_module_to_components()

func _connect_state_machine_signal() -> void:
	current_movement_logic = _movement_controller._crouch_or_other

	_state_machine.state_changed.connect(_on_state_changed)

func _debug_text() -> String:
	return str(
		"FPS: ", Engine.get_frames_per_second(), "\n",
		"Velocity: ", round(velocity), "\n",
		"Movement Speed: ", snappedf(_movement_controller.movement_speed, 0.1), "\n",
		"Walk Speed: ", snappedf(_movement_controller.walk_speed, 0.01), "\n",
		"Run Speed: ", snappedf(_movement_controller.run_speed, 0.01), "\n",
		"Slide Speed: ", snappedf(_movement_controller.slide_speed, 0.01), "\n",
		"Movement State: ", movement_states_array[_state_machine._current_state], "\n",
		"Velocity Timeout Time Left: ", _movement_controller._velocity_timeout_left, "\n",
		"Stamina: ", snappedf(_stamina_manager.stamina, 0.1), "\n",
		"On Floor: ", is_on_floor(), "\n",
		"On Wall: ", is_on_wall(), "\n",
		"Camera FOV: ", snappedf(%Camera.fov, 0.1), "\n",
		"Coyote Time Left: ", snappedf(_state_machine._coyote_time_left, 0.01)
	)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_build_player_context_data()
	_connect_state_machine_signal()

## Human-readable labels for [enum StateMachine.MovementStates]; indexed by the enum's integer value when rendering the debug overlay.
@onready var movement_states_array: Array[String] = ["IDLE", "WALK", "RUN", "CROUCH", "SLIDE", "JUMP", "DOUBLE_JUMP", "WALL_JUMP", "FALL"]
func _process(_delta: float) -> void:
	$Debug.text = _debug_text()

func _physics_process(delta: float) -> void:
	current_movement_logic.call()

	velocity = _movement_controller.compute_movement_velocity()
	move_and_slide()
