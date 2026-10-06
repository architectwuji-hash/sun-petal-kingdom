extends CharacterBody3D

## Aldric — Suji Village blacksmith.
## Wanders his forge during the day; goes home (Cottage 4) at night.
## Talk to him to access the Blacksmith UI.

const MODEL_PATH := "res://assets/models/characters/male_villager/male_villager.fbx"
const ANIM_DIR  := "res://assets/animations/npc/male_villager/"
const ANIM_FILES := {
	"Idle": "Idle.fbx",
	"Walk": "Standard Walk.fbx",
	"Wave": "Waving Gesture.fbx",
}

const NPC_NAME         := "Aldric"
const WANDER_RADIUS    := 8.0
const MOVE_SPEED       := 2.2
const NIGHT_SPEED      := 3.2
const WAVE_DISTANCE    := 6.5
const INTERACT_RANGE   := 4.0
const GRAVITY          := -20.0
const WANDER_WAIT_MIN  := 2.0
const WANDER_WAIT_MAX  := 5.0
const HOME_ARRIVE_DIST := 2.0

## Set in scene — the daytime work position (near blacksmith)
@export var work_position: Vector3 = Vector3(221.0, 3.5, 116.0)
## Set in scene — the home cottage position (Cottage 4)
@export var home_position: Vector3 = Vector3(196.0, 2.8, 127.0)

## Which cottage this NPC belongs to (set in scene or by VillageManager).
@export var house_id: String = "cottage_4"
## Override the displayed name (used for replacement NPCs).
var display_name: String = ""

var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _target_pos: Vector3
var _wander_timer := 0.0
var _waving := false
var _is_night := false
var _at_home := false
var _player_ref: Node = null
var _dialogue_canvas: CanvasLayer = null
var _dnc: Node = null   # DayNightCycle reference
var _walking_in := false   # True while NPC is walking from entrance to home

func _ready() -> void:
	# If house not yet repaired, go dormant until VillageManager activates us.
	if house_id != "" and not VillageManager.is_repaired(house_id):
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false
		VillageManager.register_dormant_npc(house_id, self)
		return
	add_to_group("interactable")
	_target_pos = work_position
	_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	_spawn_model()
	_add_collision()
	_add_label()
	# Connect to day/night cycle
	_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc == null:
		# Try again after one frame (DayNightCycle may be deferred)
		await get_tree().process_frame
		_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc != null:
		_dnc.night_started.connect(_on_night_started)
		_dnc.day_started.connect(_on_day_started)
		# Sync with current time
		if _dnc.is_night():
			_on_night_started()

func _on_night_started() -> void:
	_is_night = true
	_at_home = false
	_target_pos = home_position

func _on_day_started() -> void:
	_is_night = false
	_at_home = false
	_target_pos = work_position
	_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)

func _spawn_model() -> void:
	var packed = load(MODEL_PATH)
	if packed == null:
		push_warning("MaleVillager: model not found at " + MODEL_PATH)
		_add_placeholder()
		return
	var model: Node3D = packed.instantiate()
	model.scale = Vector3(0.01, 0.01, 0.01)
	add_child(model)
	var fbx_anim: AnimationPlayer = _find_anim_player(model)
	if fbx_anim != null:
		fbx_anim.active = false
	var skel: Skeleton3D = _find_skeleton(model)
	if skel != null:
		_strip_mixamo_prefix(skel)
		_fix_skin_bind_names(model)
	_load_animations.call_deferred()

func _add_placeholder() -> void:
	var mesh_inst := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.8
	mesh_inst.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.9
	add_child(mesh_inst)

func _load_animations() -> void:
	var skeleton: Skeleton3D = _find_skeleton(self)
	if skeleton == null:
		push_warning("MaleVillager: no Skeleton3D found — animations disabled")
		return
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)
	var anim_root: Node = _anim_player.get_node(_anim_player.root_node)
	var skel_rel: NodePath = anim_root.get_path_to(skeleton)
	var lib := AnimationLibrary.new()
	for anim_name: String in ANIM_FILES:
		var fpath: String = ANIM_DIR + str(ANIM_FILES[anim_name])
		var packed = load(fpath)
		if packed == null:
			push_warning("MaleVillager: animation not found: " + fpath)
			continue
		var anim_root_node: Node3D = packed.instantiate()
		var src_player: AnimationPlayer = _find_anim_player(anim_root_node)
		if src_player == null:
			anim_root_node.queue_free()
			continue
		for lib_name in src_player.get_animation_library_list():
			var src_lib: AnimationLibrary = src_player.get_animation_library(lib_name)
			for src_name in src_lib.get_animation_list():
				if src_name == "RESET":
					continue
				var anim: Animation = src_lib.get_animation(src_name).duplicate(true)
				for ti: int in anim.get_track_count():
					var subpath: String = anim.track_get_path(ti).get_concatenated_subnames()
					if subpath.begins_with("mixamorig:") or subpath.begins_with("mixamorig_"):
						subpath = subpath.substr(10)
					anim.track_set_path(ti, NodePath(str(skel_rel) + ":" + subpath))
				if anim_name in ["Idle", "Walk"]:
					anim.loop_mode = Animation.LOOP_LINEAR
				if not lib.has_animation(anim_name):
					lib.add_animation(anim_name, anim)
		anim_root_node.queue_free()
	_anim_player.add_animation_library("", lib)
	_play_anim("Idle")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children(true):
		var r: AnimationPlayer = _find_anim_player(child)
		if r != null:
			return r
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children(true):
		var r: Skeleton3D = _find_skeleton(child)
		if r != null:
			return r
	return null

func _strip_mixamo_prefix(skel: Skeleton3D) -> void:
	for i: int in skel.get_bone_count():
		var bname: String = skel.get_bone_name(i)
		if bname.begins_with("mixamorig:") or bname.begins_with("mixamorig_"):
			skel.set_bone_name(i, bname.substr(10))

func _fix_skin_bind_names(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.skin != null:
			var sk: Skin = mi.skin.duplicate()
			var changed := false
			for b: int in sk.get_bind_count():
				var bn: String = String(sk.get_bind_name(b))
				if bn.begins_with("mixamorig:") or bn.begins_with("mixamorig_"):
					sk.set_bind_name(b, bn.substr(10))
					changed = true
			if changed:
				mi.skin = sk
	for child: Node in node.get_children(true):
		_fix_skin_bind_names(child)

func _add_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "[E] Talk to Aldric"
	lbl.position = Vector3(0, 2.2, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.92, 0.4)
	lbl.visible = false
	lbl.name = "InteractLabel"
	add_child(lbl)

func _input(event: InputEvent) -> void:
	if _dialogue_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_close_dialogue()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")

	var label: Label3D = get_node_or_null("InteractLabel")

	if _player_ref != null:
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if label:
			label.visible = dist < INTERACT_RANGE + 2.0 and not _is_night
		if not _is_night and dist < WAVE_DISTANCE and not _waving:
			_waving = true
			_play_anim("Wave")
			var ld: Vector3 = (_player_ref.global_position as Vector3) - global_position
			ld.y = 0.0
			if ld.length() > 0.01:
				look_at(global_position + ld, Vector3.UP)
		elif (dist >= WAVE_DISTANCE or _is_night) and _waving:
			_waving = false
		if _waving:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
	else:
		if label:
			label.visible = false

	# Walk-in: newly arrived NPC walks straight to home first.
	if _walking_in:
		var dist_home := global_position.distance_to(home_position)
		if dist_home < HOME_ARRIVE_DIST:
			_walking_in = false
			_target_pos = work_position
			_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
			_play_anim("Idle")
		else:
			var dir := (home_position - global_position).normalized()
			dir.y = 0.0
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			_play_anim("Walk")
			if dir.length() > 0.01:
				look_at(global_position + dir, Vector3.UP)
		move_and_slide()
		return

	# Night: walk straight home and stay put
	if _is_night:
		if _at_home:
			velocity.x = 0.0
			velocity.z = 0.0
			_play_anim("Idle")
			move_and_slide()
			return
		var dist_home := global_position.distance_to(home_position)
		if dist_home < HOME_ARRIVE_DIST:
			_at_home = true
			velocity.x = 0.0
			velocity.z = 0.0
			_play_anim("Idle")
			move_and_slide()
			return
		var dir := (home_position - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * NIGHT_SPEED
		velocity.z = dir.z * NIGHT_SPEED
		_play_anim("Walk")
		if dir.length() > 0.01:
			look_at(global_position + dir, Vector3.UP)
		move_and_slide()
		return

	# Daytime wander around work_position
	_wander_timer -= delta
	var dist_to_target := global_position.distance_to(_target_pos)
	if dist_to_target < 0.5:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")
		if _wander_timer <= 0.0:
			_pick_new_target()
			_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	else:
		var dir := (_target_pos - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_play_anim("Walk")
		if dir.length() > 0.01:
			look_at(global_position + dir, Vector3.UP)
	move_and_slide()

func _pick_new_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(3.0, WANDER_RADIUS)
	_target_pos = work_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _play_anim(anim_name: String) -> void:
	if _anim_player == null or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name)
	elif anim_name != "Idle":
		_play_anim("Idle")

## Called by VillageManager when the house is repaired and the NPC should walk in.
func begin_walk_in() -> void:
	_walking_in = true
	_target_pos = home_position
	add_to_group("interactable")
	_spawn_model()
	_add_collision()
	_add_label()
	# Connect DNC
	if _dnc == null:
		_dnc = get_tree().get_first_node_in_group("day_night")
		if _dnc != null:
			_dnc.night_started.connect(_on_night_started)
			_dnc.day_started.connect(_on_day_started)

## Call this when the NPC takes fatal damage.
func report_death() -> void:
	VillageManager.report_npc_death(house_id)
	queue_free()

func _get_display_name() -> String:
	return display_name if display_name != "" else NPC_NAME

func interact(player: Node) -> void:
	## Called by the player's interact system when [E] is pressed near Aldric.
	## Opens the Blacksmith UI.
	if _is_night:
		return  # Aldric is asleep
	if _dialogue_canvas != null:
		return
	if player != null:
		var ld: Vector3 = (player.global_position as Vector3) - global_position
		ld.y = 0.0
		if ld.length() > 0.01:
			look_at(global_position + ld, Vector3.UP)
	if player and player.has_method("set"):
		player.set("_input_blocked", true)

	# --- Open Blacksmith UI ---
	# TODO: replace this placeholder with the real blacksmith scene/signal
	# e.g. get_tree().root.get_node("BlacksmithUI").open()
	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(480, 200)
	panel.position = Vector2(-240, -220)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = NPC_NAME + "  ⚒"
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = "Welcome to my forge! What can I craft for you?"
	msg_lbl.add_theme_font_size_override("font_size", 20)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var craft_btn := Button.new()
	craft_btn.text = "⚒ Blacksmith"
	craft_btn.pressed.connect(_open_blacksmith_ui.bind(player))
	hbox.add_child(craft_btn)

	var close_btn := Button.new()
	close_btn.text = "Leave  [E]"
	close_btn.pressed.connect(_close_dialogue)
	hbox.add_child(close_btn)

	player.add_child(_dialogue_canvas)

func _open_blacksmith_ui(player: Node) -> void:
	## Opens the full Blacksmith shop UI.
	## Items: Miner's Pick, Iron Sword.
	## Payment: Raw Metal Ore (required) + Coin OR Meat OR Fruit.
	_close_dialogue()  # close the greeting panel first

	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(540, 340)
	panel.position = Vector2(-270, -170)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var title_lbl := Label.new()
	title_lbl.text = "⚒  Aldric's Forge"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	title_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_lbl)

	# Inventory summary
	var inv_lbl := Label.new()
	inv_lbl.name = "InvSummary"
	inv_lbl.add_theme_font_size_override("font_size", 14)
	inv_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	vbox.add_child(inv_lbl)
	_refresh_inv_label(player, inv_lbl)

	# Separator
	vbox.add_child(HSeparator.new())

	# --- SHOP ITEMS ---
	# Miner's Pick: 3 Ore  +  ( 2 Coin  OR  5 Meat  OR  10 Fruit )
	_add_shop_item(
		vbox, player, inv_lbl,
		"⛏  Miner's Pick",
		"miners_pick",
		3,   # ore cost
		{ "coin": 2, "meat": 5, "fruit": 10 }
	)

	vbox.add_child(HSeparator.new())

	# Iron Sword: 5 Ore  +  ( 8 Coin  OR  18 Meat  OR  32 Fruit )
	_add_shop_item(
		vbox, player, inv_lbl,
		"⚔  Iron Sword",
		"iron_sword",
		5,   # ore cost
		{ "coin": 8, "meat": 18, "fruit": 32 }
	)

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Leave  [E]"
	close_btn.pressed.connect(_close_dialogue)
	vbox.add_child(close_btn)

	player.add_child(_dialogue_canvas)


func _add_shop_item(
		vbox: VBoxContainer,
		player: Node,
		inv_lbl: Label,
		label: String,
		item_id: String,
		ore_cost: int,
		pay_options: Dictionary) -> void:
	## Adds a single craftable item row to the shop VBox.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vbox.add_child(row)

	var item_lbl := Label.new()
	item_lbl.text = label
	item_lbl.add_theme_font_size_override("font_size", 17)
	row.add_child(item_lbl)

	# Cost description
	var cost_parts: Array[String] = []
	for pay_item: String in pay_options:
		var icon: String = { "coin": "🪙", "meat": "🥩", "fruit": "🍊" }.get(pay_item, "")
		cost_parts.append("%d %s%s" % [pay_options[pay_item], icon, pay_item.capitalize()])
	var cost_lbl := Label.new()
	cost_lbl.text = "  %d Ore  +  ( %s )" % [ore_cost, "  or  ".join(cost_parts)]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	row.add_child(cost_lbl)

	# Craft buttons (one per payment type)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	row.add_child(btn_row)

	var pay_icons := { "coin": "🪙", "meat": "🥩", "fruit": "🍊" }
	for pay_item: String in pay_options:
		var pay_qty: int = pay_options[pay_item]
		var icon: String = pay_icons.get(pay_item, "")
		var btn := Button.new()
		btn.text = "Craft (%s%d %s)" % [icon, pay_qty, pay_item.capitalize()]
		btn.pressed.connect(_craft_item.bind(player, inv_lbl, item_id, ore_cost, pay_item, pay_qty, row))
		btn_row.add_child(btn)


func _craft_item(
		player: Node,
		inv_lbl: Label,
		item_id: String,
		ore_cost: int,
		pay_item: String,
		pay_qty: int,
		row: VBoxContainer) -> void:
	## Attempt to craft an item from the blacksmith shop.

	# DEV BYPASS: allow crafting without checking materials.
	# TODO: remove "can_afford = true" once Inventory is fully wired up.
	var has_ore  := _bs_count(player, "raw_metal_ore") >= ore_cost
	var has_pay  := _bs_count(player, pay_item) >= pay_qty
	var can_afford := has_ore and has_pay
	can_afford = true   # ← DEV bypass

	if not can_afford:
		_bs_feedback(row, "Not enough resources.")
		return

	# Consume
	if player.has_method("remove_item"):
		player.remove_item("raw_metal_ore", ore_cost)
		player.remove_item(pay_item, pay_qty)
	# Grant item
	if player.has_method("add_item"):
		player.add_item(item_id)

	# Refresh inventory line
	_refresh_inv_label(player, inv_lbl)
	_bs_feedback(row, "✓ Crafted %s!" % item_id.replace("_", " ").capitalize())


func _refresh_inv_label(player: Node, lbl: Label) -> void:
	var ore   := _bs_count(player, "raw_metal_ore")
	var coin  := _bs_count(player, "coin")
	var meat  := _bs_count(player, "meat")
	var fruit := _bs_count(player, "fruit")
	lbl.text = "Ore: %d   🪙Coin: %d   🥩Meat: %d   🍊Fruit: %d" % [ore, coin, meat, fruit]


func _bs_feedback(row: VBoxContainer, msg: String) -> void:
	var existing: Node = row.get_node_or_null("Feedback")
	if existing:
		existing.queue_free()
	var fb := Label.new()
	fb.name = "Feedback"
	fb.text = msg
	var ok := msg.begins_with("✓")
	fb.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.3) if ok else Color(1.0, 0.35, 0.35))
	fb.add_theme_font_size_override("font_size", 14)
	row.add_child(fb)


func _bs_count(player: Node, item: String) -> int:
	if player == null:
		return 0
	if "inventory" in player:
		return player.inventory.get(item, 0) as int
	return 0

func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var player: Node = _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if player and player.has_method("set"):
		player.set("_input_blocked", false)
