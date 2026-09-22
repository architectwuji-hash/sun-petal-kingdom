extends StaticBody3D
class_name DummyTarget

signal died

@export var max_health: int = 50

var health: int = max_health

@onready var mesh: MeshInstance3D = $Mesh
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	health = max_health
	_update_label()


func take_damage(amount: int) -> void:
	health -= amount
	_update_label()
	if health <= 0:
		die()


func die() -> void:
	emit_signal("died")
	queue_free()


func _update_label() -> void:
	health_label.text = str(health) + " / " + str(max_health)
