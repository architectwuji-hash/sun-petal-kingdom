extends Node3D

signal healed(orb: Node3D)


func _ready() -> void:
	$PickupArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player"):
		healed.emit(self)
		queue_free()


func _process(delta: float) -> void:
	rotation.y += delta * 2.2
	position.y = sin(Time.get_ticks_msec() * 0.002) * 0.18 + 0.4
