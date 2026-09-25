extends Node3D

signal collected(petal: Node3D)


func _ready() -> void:
	$Area3D.body_entered.connect(_on_body)


func _process(delta: float) -> void:
	rotation.y += delta * 1.8


func _on_body(body: Node3D) -> void:
	if body is CharacterBody3D:
		collected.emit(self)
		queue_free()
