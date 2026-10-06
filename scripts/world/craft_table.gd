extends Node3D
## CraftTable — attach as a child Node3D on the craft table object (or the root if standalone).
## Player presses [E] to open the crafting menu.
##
## Starter recipe:
##   3 Stone  →  1 Raw Metal Ore  (instant, no wait)

const INTERACT_RANGE := 4.0
const LABEL_HEIGHT   := 1.8

var _label: Label3D = null
var _player_ref: Node = null
var _dialogue_canvas: CanvasLayer = null

func _ready() -> void:
	add_to_group("interactable")
	_add_label()

func _add_label() -> void:
	_label = Label3D.new()
	_label.text = "[E] Craft Table"
	_label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
	_label.font_size = 28
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.55, 1.0, 0.55)
	_label.visible = false
	_label.name = "CraftLabel"
	add_child(_label)

func _process(_delta: float) -> void:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref == null:
		return
	var origin: Vector3 = get_parent().global_position if get_parent() is Node3D else global_position
	var dist := origin.distance_to(_player_ref.global_position)
	if _label:
		_label.visible = dist < INTERACT_RANGE + 2.0

func _input(event: InputEvent) -> void:
	if _dialogue_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_close_dialogue()

## Called by the player's interact system when [E] is pressed.
func interact(player: Node) -> void:
	if _dialogue_canvas != null:
		return
	_player_ref = player
	_show_craft_menu(player)

# ---------------------------------------------------------------------------
#  UI
# ---------------------------------------------------------------------------

func _show_craft_menu(player: Node) -> void:
	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(500, 240)
	panel.position = Vector2(-250, -260)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚒ Craft Table"
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_add_inventory_line(player, vbox)

	var recipe_lbl := Label.new()
	recipe_lbl.text = "Recipe:  3 Stone  →  1 Raw Metal Ore"
	recipe_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(recipe_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var smelt1_btn := Button.new()
	smelt1_btn.text = "Smelt ×1"
	smelt1_btn.pressed.connect(_smelt.bind(player, vbox, 1))
	hbox.add_child(smelt1_btn)

	var smelt5_btn := Button.new()
	smelt5_btn.text = "Smelt ×5"
	smelt5_btn.pressed.connect(_smelt.bind(player, vbox, 5))
	hbox.add_child(smelt5_btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [E]"
	close_btn.pressed.connect(_close_dialogue)
	hbox.add_child(close_btn)

	player.add_child(_dialogue_canvas)

func _add_inventory_line(player: Node, vbox: VBoxContainer) -> void:
	var stone := _count(player, "stone")
	var ore   := _count(player, "raw_metal_ore")
	var info_lbl := Label.new()
	info_lbl.name = "InvLine"
	info_lbl.text = "Stone: %d    Raw Metal Ore: %d" % [stone, ore]
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(info_lbl)

# ---------------------------------------------------------------------------
#  Crafting logic
# ---------------------------------------------------------------------------

func _smelt(player: Node, vbox: VBoxContainer, n: int) -> void:
	var stone_needed := 3 * n

	# DEV BYPASS: allow smelting even without materials.
	# TODO: remove the "can_afford = true" override once Inventory is ready.
	var can_afford := _count(player, "stone") >= stone_needed
	can_afford = true   # ← DEV bypass

	if not can_afford:
		_show_feedback(vbox, "Need %d Stone to smelt %d ore." % [stone_needed, n])
		return

	# Remove stone, add ore
	if player.has_method("remove_item"):
		player.remove_item("stone", stone_needed)
	if player.has_method("add_item"):
		for _i in n:
			player.add_item("raw_metal_ore")

	# Refresh inventory line
	var inv_line: Label = vbox.get_node_or_null("InvLine")
	if inv_line:
		var stone := _count(player, "stone")
		var ore   := _count(player, "raw_metal_ore")
		inv_line.text = "Stone: %d    Raw Metal Ore: %d" % [stone, ore]

	_show_feedback(vbox, "✓ Smelted %d Raw Metal Ore!" % n)

func _show_feedback(vbox: VBoxContainer, msg: String) -> void:
	var existing: Node = vbox.get_node_or_null("Feedback")
	if existing:
		existing.queue_free()
	var fb := Label.new()
	fb.name = "Feedback"
	fb.text = msg
	var is_ok := msg.begins_with("✓")
	fb.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.3) if is_ok else Color(1.0, 0.35, 0.35))
	fb.add_theme_font_size_override("font_size", 15)
	vbox.add_child(fb)

func _count(player: Node, item: String) -> int:
	if player == null:
		return 0
	if "inventory" in player:
		return player.inventory.get(item, 0) as int
	return 0

func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var parent := _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if parent and parent.has_method("set"):
		parent.set("_input_blocked", false)
