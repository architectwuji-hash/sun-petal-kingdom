extends Node
## SaveManager — global singleton for save / load.
## Registered as autoload "SaveManager" in project.godot.
## Press F5 to save, F9 to load.

const SAVE_PATH    := "user://savegame.json"
const SAVE_VERSION := 1

const WOOD_WALL_SCENE  := preload("res://scenes/objects/WoodWall3D.tscn")
const STONE_WALL_SCENE := preload("res://scenes/objects/StoneWall3D.tscn")

signal game_saved
signal game_loaded

## Set to true by the main menu Continue button; forest_zone_3d reads and clears it.
var load_on_next_scene: bool = false

## Temporary storage for scene transitions (temple door → interior → return).
## Set before calling change_scene_to_file; cleared by the destination zone.
var scene_transfer_data: Dictionary = {}

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			load_game()
			get_viewport().set_input_as_handled()

# ── Public API ────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data: Dictionary = {
		"version":   SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"players":   [],
		"walls":     [],
		"kipatah":   null,
		"cottages":  [],
	}

	# ── Players ───────────────────────────────────────────────────────────────
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.has_method("get_save_data"):
			data["players"].append(node.get_save_data())

	# ── Placed walls ──────────────────────────────────────────────────────────
	for wall: Node3D in get_tree().get_nodes_in_group("placed_wall"):
		var is_stone: bool = wall is StoneWall
		var wdata: Dictionary = {
			"type":  "stone" if is_stone else "wood",
			"x":     wall.global_position.x,
			"y":     wall.global_position.y,
			"z":     wall.global_position.z,
			"rot_y": wall.rotation.y,
		}
		if is_stone:
			wdata["stone_variant"] = (wall as StoneWall).stone_variant
		data["walls"].append(wdata)

	# ── Kipatah ───────────────────────────────────────────────────────────────
	var kip_nodes: Array = get_tree().get_nodes_in_group("kipatah")
	if kip_nodes.size() > 0:
		var kip: Node = kip_nodes[0]
		if kip.has_method("get_save_data"):
			data["kipatah"] = kip.get_save_data()

	# ── Cottages ─────────────────────────────────────────────────────────────────
	for cottage: Node in get_tree().get_nodes_in_group("ruined_cottage"):
		if cottage.has_method("get_save_data"):
			data["cottages"].append(cottage.get_save_data())

	# ── Write to disk ─────────────────────────────────────────────────────────
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	emit_signal("game_saved")
	print("[SaveManager] Saved → ", SAVE_PATH)
	_show_notice("Game Saved  ✓")


func load_game() -> void:
	# Unfreeze the tree first — game-over overlay pauses it, which would
	# deadlock the "await process_frame" below.
	get_tree().paused = false
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveManager] No save file found.")
		_show_notice("No Save Found")
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot open save file for reading.")
		return
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		push_error("[SaveManager] Save file corrupt or invalid.")
		_show_notice("Save File Corrupt!")
		return
	var data: Dictionary = parsed as Dictionary

	# ── Players ───────────────────────────────────────────────────────────────
	var saved_players: Array = data.get("players", [])
	var live_players: Array  = get_tree().get_nodes_in_group("player")
	for i: int in range(mini(saved_players.size(), live_players.size())):
		var node: Node = live_players[i]
		if node.has_method("apply_save_data"):
			node.apply_save_data(saved_players[i])

	# ── Walls: clear all placed walls, then respawn from save ─────────────────
	for wall: Node in get_tree().get_nodes_in_group("placed_wall"):
		wall.queue_free()

	# Wait one frame so queue_free flushed before we add new walls
	await get_tree().process_frame

	var saved_walls: Array = data.get("walls", [])
	for wd: Dictionary in saved_walls:
		var scene: PackedScene = STONE_WALL_SCENE \
			if wd.get("type", "wood") == "stone" \
			else WOOD_WALL_SCENE
		var w: Node3D = scene.instantiate()
		w.global_position = Vector3(
			float(wd.get("x", 0.0)),
			float(wd.get("y", 0.0)),
			float(wd.get("z", 0.0))
		)
		w.rotation.y = float(wd.get("rot_y", 0.0))
		if w is StoneWall and wd.has("stone_variant"):
			(w as StoneWall).stone_variant = int(wd["stone_variant"])
		get_tree().root.add_child(w)

	# ── Kipatah ───────────────────────────────────────────────────────────────
	var kip_data: Variant = data.get("kipatah", null)
	if kip_data is Dictionary:
		var kip_nodes: Array = get_tree().get_nodes_in_group("kipatah")
		if kip_nodes.size() > 0:
			var kip: Node = kip_nodes[0]
			if kip.has_method("apply_save_data"):
				kip.apply_save_data(kip_data as Dictionary)

	# ── Cottages ─────────────────────────────────────────────────────────────────
	var saved_cottages: Array = data.get("cottages", [])
	if saved_cottages.size() > 0:
		var live_cottages: Array = get_tree().get_nodes_in_group("ruined_cottage")
		for cd: Dictionary in saved_cottages:
			for cottage: Node in live_cottages:
				if cottage.name == cd.get("node_name", ""):
					if cottage.has_method("apply_save_data"):
						cottage.apply_save_data(cd)
					break

	emit_signal("game_loaded")
	print("[SaveManager] Loaded ← ", SAVE_PATH)
	_show_notice("Game Loaded  ✓")

# ── HUD notice (brief on-screen flash) ───────────────────────────────────────

func _show_notice(msg: String) -> void:
	# Spawn a floating label on the current viewport's canvas
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color",         Color(1.0, 1.0, 0.6, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.position.y = 60.0
	lbl.size = Vector2(400, 40)
	lbl.position.x = -200.0
	canvas.add_child(lbl)
	get_tree().root.add_child(canvas)
	# Fade out after 1.8 s
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(canvas.queue_free)
