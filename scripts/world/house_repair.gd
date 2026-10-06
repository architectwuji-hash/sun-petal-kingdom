extends Node3D
## HouseRepair — attach to a cottage node.
## Player presses [E] nearby to repair the house, spending materials.
## On success, notifies VillageManager which spawns the NPC.

@export var house_id: String = ""          # e.g. "cottage_4"
@export var repair_label_text: String = "" # override shown in prompt; auto-set if empty

## Materials required to repair (item name -> quantity).
@export var repair_materials: Dictionary = { "Wood": 8, "Stone": 5 }

const INTERACT_RANGE := 5.0
const LABEL_HEIGHT   := 3.2

var _repaired    := false
var _label: Label3D  = null
var _player_ref: Node = null
var _dialogue_canvas: CanvasLayer = null

func _ready() -> void:
	add_to_group("interactable")
	_repaired = VillageManager.is_repaired(house_id)
	if not _repaired:
		_add_label()

func _add_label() -> void:
	_label = Label3D.new()
	_label.text = repair_label_text if repair_label_text != "" else "[E] Repair House"
	_label.position = Vector3(0, LABEL_HEIGHT, 0)
	_label.font_size = 28
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.7, 0.2)
	_label.visible = false
	_label.name = "RepairLabel"
	add_child(_label)

func _process(_delta: float) -> void:
	if _repaired:
		return
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref == null:
		return
	# Use parent node global_position for distance (this node is a child of the cottage).
	var origin: Vector3 = get_parent().global_position if get_parent() is Node3D else global_position
	var dist := origin.distance_to(_player_ref.global_position)
	if _label:
		_label.visible = dist < INTERACT_RANGE + 2.0

func _input(event: InputEvent) -> void:
	if _repaired or _dialogue_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_close_dialogue()

## Called by the player's interact system when [E] is pressed.
func interact(player: Node) -> void:
	if _repaired:
		return
	if _dialogue_canvas != null:
		return
	_player_ref = player

	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(460, 200)
	panel.position = Vector2(-230, -220)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Repair House  🏚️"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Build cost string.
	var cost_str := ""
	for item in repair_materials:
		if cost_str != "": cost_str += ", "
		cost_str += str(int(repair_materials[item])) + " " + str(item)
	var cost_lbl := Label.new()
	cost_lbl.text = "Requires: " + cost_str
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cost_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var repair_btn := Button.new()
	repair_btn.text = "🔨 Repair"
	repair_btn.pressed.connect(_attempt_repair.bind(player))
	hbox.add_child(repair_btn)

	var close_btn := Button.new()
	close_btn.text = "Cancel  [E]"
	close_btn.pressed.connect(_close_dialogue)
	hbox.add_child(close_btn)

	player.add_child(_dialogue_canvas)

func _attempt_repair(player: Node) -> void:
	# Check if the player has enough materials.
	# Assumes the player has an Inventory node with has_item(name, qty) and remove_item(name, qty).
	var inventory: Node = null
	if player.has_node("Inventory"):
		inventory = player.get_node("Inventory")

	var can_afford := true
	if inventory != null:
		for item in repair_materials:
			if not inventory.has_item(item, repair_materials[item]):
				can_afford = false
				break
	# If no inventory system yet, allow repair freely (dev mode).
	# Remove the line below once inventory is implemented.
	can_afford = true   # TODO: remove when Inventory is ready

	if not can_afford:
		_show_feedback("Not enough materials.")
		return

	# Consume materials.
	if inventory != null:
		for item in repair_materials:
			inventory.remove_item(item, repair_materials[item])

	_close_dialogue()
	_finish_repair()

func _finish_repair() -> void:
	_repaired = true
	if _label:
		_label.queue_free()
		_label = null
	# Notify village manager — this triggers NPC spawn.
	VillageManager.repair_house(house_id)

func _show_feedback(msg: String) -> void:
	if _dialogue_canvas == null:
		return
	var panel := _dialogue_canvas.get_child(0)
	if panel == null:
		return
	var vbox := panel.get_child(0)
	if vbox == null:
		return
	var fb := Label.new()
	fb.text = msg
	fb.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	fb.add_theme_font_size_override("font_size", 15)
	vbox.add_child(fb)

func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var parent := _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if parent and parent.has_method("set"):
		parent.set("_input_blocked", false)
