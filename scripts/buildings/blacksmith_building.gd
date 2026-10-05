extends Node3D
## Blacksmith interactable building.
## Place this node in FantasyForest.tscn at the blacksmith location.
## The player presses E within INTERACT_RANGE to open the crafting panel.
##
## RECIPES format:
##   name   – internal identifier (used as result item key)
##   emoji  – display emoji
##   label  – human-readable name
##   result – item added to inventory on craft (usually same as name)
##   count  – how many are produced (default 1)
##   cost   – Dictionary of { item_name: quantity } materials consumed

const RECIPES := [
	{
		"name":   "campfire_kit",
		"emoji":  "🔥",
		"label":  "Campfire Kit",
		"result": "campfire_kit",
		"count":  1,
		"cost":   {"wood": 4, "stone": 2},
	},
	{
		"name":   "potion",
		"emoji":  "🧪",
		"label":  "Healing Potion",
		"result": "potion",
		"count":  1,
		"cost":   {"mushroom": 3, "cowhide": 1},
	},
	{
		"name":   "hide_armor",
		"emoji":  "🦺",
		"label":  "Hide Armour",
		"result": "hide_armor",
		"count":  1,
		"cost":   {"cowhide": 4, "monkey_fur": 2},
	},
	{
		"name":   "stone_blade",
		"emoji":  "🗡️",
		"label":  "Stone Blade",
		"result": "stone_blade",
		"count":  1,
		"cost":   {"stone": 5, "wood": 2},
	},
]

@export var prompt_text: String = "[E] Blacksmith ⚒️"

func _ready() -> void:
	add_to_group("interactable")

	## Floating label above the building entrance
	var lbl := Label3D.new()
	lbl.text = prompt_text
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 5.0, 0)
	lbl.no_depth_test = true
	lbl.modulate = Color(0.8, 0.9, 1.0)
	add_child(lbl)


func interact(player: Node) -> void:
	if player.has_method("open_blacksmith_ui"):
		player.open_blacksmith_ui(RECIPES)
