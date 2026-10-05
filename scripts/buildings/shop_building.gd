extends Node3D
## General Store interactable building.
## Place this node (or attach this script to a MeshInstance3D / StaticBody3D)
## in FantasyForest.tscn at the store location.
## The player presses E within INTERACT_RANGE to open the shop panel.

const SHOP_ITEMS := [
	{"name": "fruit",    "emoji": "🍊", "label": "Fruit",    "cost": 5},
	{"name": "mushroom", "emoji": "🍄", "label": "Mushroom", "cost": 3},
	{"name": "wood",     "emoji": "🪵", "label": "Wood",     "cost": 6},
	{"name": "stone",    "emoji": "🪨", "label": "Stone",    "cost": 6},
	{"name": "meat",     "emoji": "🥩", "label": "Meat",     "cost": 10},
]

@export var prompt_text: String = "[E] Open Shop 🏪"

func _ready() -> void:
	add_to_group("interactable")

	## Floating label above the building entrance
	var lbl := Label3D.new()
	lbl.text = prompt_text
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 5.0, 0)
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.92, 0.5)
	add_child(lbl)


func interact(player: Node) -> void:
	if player.has_method("open_shop_ui"):
		player.open_shop_ui(SHOP_ITEMS)
