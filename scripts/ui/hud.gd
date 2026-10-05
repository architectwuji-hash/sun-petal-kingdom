extends CanvasLayer
class_name HUD

@onready var health_bar: ProgressBar = $StatsPanel/VBox/HealthRow/HealthBar
@onready var ocali_bar: ProgressBar = $StatsPanel/VBox/OcaliRow/OcaliBar
@onready var level_label: Label = $StatsPanel/VBox/LevelRow/LevelLabel
@onready var xp_bar: ProgressBar = $StatsPanel/VBox/XPBar
@onready var death_screen: Control = $DeathScreen
@onready var slot_container: HBoxContainer = $SlotBar/Slots

var _player: Player = null
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _kills: int = 0

## Resource display — created dynamically in _build_resource_panel()
var _res_panel: PanelContainer = null
var _res_labels: Dictionary = {}   # "wood" → Label, "stone" → Label, "mushroom" → Label


func _ready() -> void:
	_build_resource_panel()
	death_screen.visible = false
	for i in range(4):
		var panel: PanelContainer = slot_container.get_child(i) as PanelContainer
		_slot_panels.append(panel)
		_slot_labels.append(panel.get_child(0) as Label)


func connect_to_player(player: Player) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.ocali_changed.connect(_on_ocali_changed)
	player.level_changed.connect(_on_level_changed)
	player.died.connect(_on_player_died)
	player.flower_loadout.slot_changed.connect(_on_slot_changed)
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	ocali_bar.max_value = player.max_ocali
	ocali_bar.value = player.ocali
	_on_level_changed(player.level, player.xp, player._get_xp_required())
	_refresh_slots()
	player.inventory_changed.connect(_on_inventory_changed)
	# Seed initial values
	for item in ["wood", "stone", "mushroom"]:
		_on_inventory_changed(item, player.get_item_count(item))


func _on_inventory_changed(item: String, new_count: int) -> void:
	if _res_labels.has(item):
		_res_labels[item].text = _res_icon(item) + " " + str(new_count)


func _res_icon(item: String) -> String:
	match item:
		"wood":     return "Wood"
		"stone":    return "Stone"
		"mushroom": return "Shroom"
		_:          return item.capitalize()


func _build_resource_panel() -> void:
	## Creates a small panel in the bottom-right corner showing
	## Wood / Stone / Mushroom counts. Built in code so the .tscn stays clean.
	var panel := PanelContainer.new()
	panel.name = "ResourcePanel"
	# Anchor bottom-right
	panel.anchor_left   = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -180.0
	panel.offset_top    = -120.0
	panel.offset_right  = -12.0
	panel.offset_bottom = -12.0
	# Style: semi-transparent dark background
	var style := StyleBoxFlat.new()
	style.bg_color          = Color(0.0, 0.0, 0.0, 0.55)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 10.0
	style.content_margin_right  = 10.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	# Title row
	var title := Label.new()
	title.text = "Resources"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5, 1.0))
	vbox.add_child(title)
	# One label per resource
	for item: String in ["wood", "stone", "mushroom"]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		lbl.text = _res_icon(item) + " 0"
		vbox.add_child(lbl)
		_res_labels[item] = lbl
	_res_panel = panel


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_ocali_changed(current: int, maximum: int) -> void:
	ocali_bar.max_value = maximum
	ocali_bar.value = current


func _on_level_changed(new_level: int, current_xp: int, required_xp: int) -> void:
	level_label.text = str(new_level) + "  —  " + str(current_xp) + " / " + str(required_xp) + " XP"
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp


func _on_player_died() -> void:
	death_screen.visible = true
	await get_tree().create_timer(3.0).timeout
	death_screen.visible = false


func _on_slot_changed(_index: int, _flower: String) -> void:
	_refresh_slots()


func increment_kills() -> void:
	_kills += 1


func _refresh_slots() -> void:
	if _player == null:
		return
	var loadout: FlowerLoadout = _player.flower_loadout
	for i in range(4):
		_slot_labels[i].text = _abbr(loadout.slots[i])
		if i == loadout.active_slot:
			_slot_labels[i].add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
		else:
			_slot_labels[i].remove_theme_color_override("font_color")


func _abbr(flower_name: String) -> String:
	match flower_name:
		"Sunflower":
			return "SF"
		"Rose":
			return "RT"
		"":
			return "--"
		_:
			return flower_name.left(2).to_upper()
