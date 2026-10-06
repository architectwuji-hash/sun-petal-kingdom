extends Node3D
## Cabin door trigger -- placed at the player's house door in FantasyForest.
## The player presses E to enter the cozy cabin interior.
## Uses the same interactable pattern as auros_temple_door.gd.

@export var return_position: Vector3 = Vector3(-4.0, 2.35, -1.5)
@export var label_text: String = "[E] Enter Your Home"

func _ready() -> void:
	add_to_group("interactable")

	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.8, 0.0)
	lbl.no_depth_test = true
	lbl.modulate = Color(0.95, 0.82, 0.45)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 8
	add_child(lbl)

	# Warm glowing door-frame hint light
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.3)
	glow.light_energy = 1.2
	glow.omni_range = 4.0
	glow.position = Vector3(0.0, 1.5, 0.0)
	add_child(glow)

func interact(player: Node) -> void:
	if not player.has_method("get_save_data"):
		return

	SaveManager.scene_transfer_data = player.get_save_data()
	SaveManager.scene_transfer_data["spawn_x"]      = return_position.x
	SaveManager.scene_transfer_data["spawn_y"]      = return_position.y
	SaveManager.scene_transfer_data["spawn_z"]      = return_position.z
	SaveManager.scene_transfer_data["return_scene"] = "res://scenes/world/FantasyForest.tscn"

	get_tree().change_scene_to_file("res://scenes/world/CabinInterior.tscn")
