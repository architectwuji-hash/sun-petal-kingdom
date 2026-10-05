extends Node3D
## Auros Temple door trigger — interactable entrance to the temple interior.
## Place this node at the temple entrance in FantasyForest.tscn.
## When the player presses E, it saves their state to SaveManager.scene_transfer_data
## and transitions to AurosTempleInterior.tscn.

## Return position in FantasyForest where the player re-appears when leaving the temple.
## Set this to the position just outside the temple door.
@export var return_position: Vector3 = Vector3(0.0, 2.0, -8.0)

@export var label_text: String = "[E] Enter Auros Temple 🏛️"

func _ready() -> void:
	add_to_group("interactable")

	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 32
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 3.5, 0.0)
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.92, 0.3)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 8
	add_child(lbl)

func interact(player: Node) -> void:
	## Save player state + return coordinates, then load the interior scene.
	if not player.has_method("get_save_data"):
		return

	## Store everything SaveManager needs to restore the player in the next scene
	SaveManager.scene_transfer_data = player.get_save_data()
	SaveManager.scene_transfer_data["spawn_x"]     = return_position.x
	SaveManager.scene_transfer_data["spawn_y"]     = return_position.y
	SaveManager.scene_transfer_data["spawn_z"]     = return_position.z
	SaveManager.scene_transfer_data["return_scene"] = "res://scenes/world/FantasyForest.tscn"

	## Snap player into the temple interior
	get_tree().change_scene_to_file("res://scenes/world/AurosTempleInterior.tscn")
