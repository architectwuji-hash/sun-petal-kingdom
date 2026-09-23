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


func _ready() -> void:
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
