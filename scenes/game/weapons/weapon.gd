class_name Weapon extends Node3D

@export var weapon_name: String

func initialize_weapon() -> void:
	self.name = weapon_name

func _ready() -> void:
	initialize_weapon()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
