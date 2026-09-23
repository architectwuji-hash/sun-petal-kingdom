extends Area3D
class_name SunflowerPickup

const OCALI_RESTORE: int = 1000


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var player := body as Player
		if player:
			player.restore_ocali(OCALI_RESTORE)
			queue_free()
