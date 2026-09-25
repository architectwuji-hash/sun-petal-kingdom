extends Node3D

signal collected(petal: Node3D)

var _collecting: bool = false


func _ready() -> void:
	$Area3D.body_entered.connect(_on_body)


func _process(delta: float) -> void:
	if _collecting:
		return
	rotation.y += delta * 1.8


func _on_body(body: Node3D) -> void:
	if _collecting:
		return
	if body is CharacterBody3D:
		_collecting = true
		collected.emit(self)
		_pickup_and_free()


func _pickup_and_free() -> void:
	$PickupSound.play()
	await $PickupSound.finished
	queue_free()
