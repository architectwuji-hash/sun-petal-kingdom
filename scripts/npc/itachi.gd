extends CharacterBody3D
## Itachi — Farmer NPC near ItachiFarm.
## Trade: player gives WOOD → Itachi gives MEAT + builds one fence segment.
## Has a health bar, takes damage, dies permanently (revive with 3 souls).
## If dead the player can buy his house.

# ── Model / animation ────────────────────────────────────────────────────────
const MODEL_PATH := "res://assets/models/characters/male_villager/male_villager.fbx"
const ANIM_DIR   := "res://assets/animations/npc/male_villager/"
const ANIM_FILES := {
	"Idle": "Idle.fbx",
	"Walk": "Standard Walk.fbx",
	"Wave": "Waving Gesture.fbx",
}

# ── Stats ────────────────────────────────────────────────────────────────────
const MAX_HP         := 100
const WANDER_RADIUS  := 10.0
const MOVE_SPEED     := 2.0
const GRAVITY        := -20.0
const INTERACT_RANGE := 3.5
const WAVE_DIST      := 5.5
const WANDER_WAIT_MIN := 3.0
const WANDER_WAIT_MAX := 7.0

## Wood cost per fence segment the player hands over.
const WOOD_PER_FENCE := 3
## Meat reward per trade.
const MEAT_PER_TRADE := 1
## Souls needed to revive Itachi.
const REVIVE_SOULS   := 3
## Gold to buy the house after Itachi dies.
const HOUSE_COST     := 50

# ── Fence segment world positions around the farm ─────────────────────────────
## These sit in a rough rectangle around the farm centre (≈238, 3, −13).
const FENCE_POSITIONS: Array[Vector3] = [
	Vector3(226.0, 3.0, -6.0),
	Vector3(230.0, 3.0, -4.0),
	Vector3(235.0, 3.0, -4.0),
	Vector3(240.0, 3.0, -4.0),
	Vector3(247.0, 3.0, -8.0),
	Vector3(248.0, 3.0, -13.0),
	Vector3(247.0, 3.0, -19.0),
	Vector3(240.0, 3.0, -23.0),
	Vector3(233.0, 3.0, -23.0),
	Vector3(226.0, 3.0, -19.0),
	Vector3(225.0, 3.0, -13.0),
	Vector3(225.0, 3.0, -8.0),
]

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WANDER, FACE_PLAYER, BUILDING, DEAD }
var _state: State = State.WANDER

# ── Runtime ───────────────────────────────────────────────────────────────────
var hp: int = MAX_HP
var fences_built: int = 0
var is_dead: bool = false
var house_purchased: bool = false

var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _home_pos: Vector3
var _target_pos: Vector3
var _wander_timer: float = 0.0
var _waving: bool = false
var _build_target: Vector3
var _build_wait: float = 0.0
var _player_ref: Node = null
var _dialogue_canvas: CanvasLayer = null

var _hp_bar_bg: MeshInstance3D = null
var _hp_bar_fg: MeshInstance3D = null
var _name_label: Label3D = null
var _interact_label: Label3D = null

# ── _ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("itachi_npc")
	add_to_group("hurtable")
	_home_pos   = global_position
	_target_pos = global_position
	_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	_spawn_model()
	_add_collision()
	_add_health_bar()
	_add_labels()

# ── Model helpers ─────────────────────────────────────────────────────────────

func _spawn_model() -> void:
	var packed = load(MODEL_PATH)
	if packed == null:
		_add_placeholder()
		return
	var model: Node3D = packed.instantiate()
	model.scale = Vector3(0.01, 0.01, 0.01)
	add_child(model)
	var fbx_anim: AnimationPlayer = _find_anim_player(model)
	if fbx_anim:
		fbx_anim.active = false
	var skel: Skeleton3D = _find_skeleton(model)
	if skel:
		_strip_mixamo_prefix(skel)
		_fix_skin_bind_names(model)
	_load_animations.call_deferred()

func _add_placeholder() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3; cap.height = 1.8
	mi.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.2)
	mi.material_override = mat
	mi.position.y = 0.9
	add_child(mi)

func _load_animations() -> void:
	var skeleton: Skeleton3D = _find_skeleton(self)
	if skeleton == null:
		return
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)
	var anim_root: Node = _anim_player.get_node(_anim_player.root_node)
	var skel_rel: NodePath = anim_root.get_path_to(skeleton)
	var lib := AnimationLibrary.new()
	for anim_name: String in ANIM_FILES:
		var fpath: String = ANIM_DIR + str(ANIM_FILES[anim_name])
		var p = load(fpath)
		if p == null:
			continue
		var anim_root_node: Node3D = p.instantiate()
		var src_player: AnimationPlayer = _find_anim_player(anim_root_node)
		if src_player == null:
			anim_root_node.queue_free(); continue
		for lib_name in src_player.get_animation_library_list():
			var src_lib: AnimationLibrary = src_player.get_animation_library(lib_name)
			for src_name in src_lib.get_animation_list():
				if src_name == "RESET":
					continue
				var anim: Animation = src_lib.get_animation(src_name).duplicate(true)
				for ti: int in anim.get_track_count():
					var sub: String = anim.track_get_path(ti).get_concatenated_subnames()
					if sub.begins_with("mixamorig:") or sub.begins_with("mixamorig_"):
						sub = sub.substr(10)
					anim.track_set_path(ti, NodePath(str(skel_rel) + ":" + sub))
				if anim_name in ["Idle", "Walk"]:
					anim.loop_mode = Animation.LOOP_LINEAR
				if not lib.has_animation(anim_name):
					lib.add_animation(anim_name, anim)
		anim_root_node.queue_free()
	_anim_player.add_animation_library("", lib)
	_play_anim("Idle")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node as AnimationPlayer
	for c: Node in node.get_children(true):
		var r: AnimationPlayer = _find_anim_player(c)
		if r: return r
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node as Skeleton3D
	for c: Node in node.get_children(true):
		var r: Skeleton3D = _find_skeleton(c)
		if r: return r
	return null

func _strip_mixamo_prefix(skel: Skeleton3D) -> void:
	for i: int in skel.get_bone_count():
		var bn: String = skel.get_bone_name(i)
		if bn.begins_with("mixamorig:") or bn.begins_with("mixamorig_"):
			skel.set_bone_name(i, bn.substr(10))

func _fix_skin_bind_names(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.skin != null:
			var sk: Skin = mi.skin.duplicate()
			var changed := false
			for b: int in sk.get_bind_count():
				var bn: String = String(sk.get_bind_name(b))
				if bn.begins_with("mixamorig:") or bn.begins_with("mixamorig_"):
					sk.set_bind_name(b, bn.substr(10)); changed = true
			if changed: mi.skin = sk
	for c: Node in node.get_children(true):
		_fix_skin_bind_names(c)

# ── Collision ─────────────────────────────────────────────────────────────────

func _add_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3; cap.height = 1.2
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

# ── Health bar ────────────────────────────────────────────────────────────────

func _add_health_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.name = "HealthBar"
	bar_root.position = Vector3(0.0, 2.5, 0.0)
	add_child(bar_root)

	_hp_bar_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.0, 0.1)
	_hp_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.4, 0.0, 0.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_bg.material_override = bg_mat
	bar_root.add_child(_hp_bar_bg)

	_hp_bar_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(1.0, 0.1)
	_hp_bar_fg.mesh = fg_mesh
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.1, 0.9, 0.1)
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_fg.material_override = fg_mat
	bar_root.add_child(_hp_bar_fg)

	_update_hp_bar()

func _update_hp_bar() -> void:
	if _hp_bar_fg == null:
		return
	var pct: float = float(hp) / float(MAX_HP)
	_hp_bar_fg.scale.x = pct
	_hp_bar_fg.position.x = (pct - 1.0) * 0.5
	var col: Color = Color(1.0 - pct, pct, 0.0)
	(_hp_bar_fg.material_override as StandardMaterial3D).albedo_color = col
	var bar_node: Node3D = get_node_or_null("HealthBar")
	if bar_node:
		bar_node.visible = (hp < MAX_HP and not is_dead)

# ── Labels ────────────────────────────────────────────────────────────────────

func _add_labels() -> void:
	_name_label = Label3D.new()
	_name_label.text = "Itachi"
	_name_label.position = Vector3(0.0, 2.2, 0.0)
	_name_label.font_size = 32
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color(1.0, 0.85, 0.3)
	_name_label.name = "NameLabel"
	add_child(_name_label)

	_interact_label = Label3D.new()
	_interact_label.text = "[E] Trade"
	_interact_label.position = Vector3(0.0, 1.95, 0.0)
	_interact_label.font_size = 24
	_interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_label.modulate = Color(0.7, 1.0, 0.7)
	_interact_label.visible = false
	_interact_label.name = "InteractLabel"
	add_child(_interact_label)

# ── Damage / death ────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	_update_hp_bar()
	var bar_node: Node3D = get_node_or_null("HealthBar")
	if bar_node:
		bar_node.visible = true
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	hp = 0
	_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim("Idle")
	if _name_label:
		_name_label.text = "Itachi  \U0001F480"
		_name_label.modulate = Color(0.5, 0.5, 0.5)
	if _interact_label:
		_interact_label.text = "[E] Revive / Buy House"
		_interact_label.modulate = Color(1.0, 0.4, 0.4)
	var bar_node: Node3D = get_node_or_null("HealthBar")
	if bar_node:
		bar_node.visible = false
	SaveManager.save_game()

# ── Physics / AI ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_dead:
		move_and_slide()
		return

	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player")

	var dist_to_player: float = INF
	if _player_ref != null and is_instance_valid(_player_ref):
		dist_to_player = global_position.distance_to(_player_ref.global_position)

	if _interact_label:
		_interact_label.visible = dist_to_player < INTERACT_RANGE + 2.5

	match _state:
		State.WANDER:
			_tick_wander(delta, dist_to_player)
		State.FACE_PLAYER:
			_tick_face_player(delta, dist_to_player)
		State.BUILDING:
			_tick_building(delta)

func _tick_wander(delta: float, dist_to_player: float) -> void:
	if dist_to_player < WAVE_DIST:
		_state = State.FACE_PLAYER
		_waving = true
		_play_anim("Wave")
		_look_at_player()
		velocity.x = 0.0; velocity.z = 0.0
		move_and_slide()
		return

	_wander_timer -= delta
	var dist_to_target := global_position.distance_to(_target_pos)
	if dist_to_target < 0.5:
		velocity.x = 0.0; velocity.z = 0.0
		_play_anim("Idle")
		if _wander_timer <= 0.0:
			_pick_wander_target()
			_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	else:
		var dir := (_target_pos - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_play_anim("Walk")
		_look_dir(dir)
	move_and_slide()

func _tick_face_player(delta: float, dist_to_player: float) -> void:
	if dist_to_player >= WAVE_DIST + 1.0:
		_state = State.WANDER
		_waving = false
		return
	_look_at_player()
	velocity.x = 0.0; velocity.z = 0.0
	move_and_slide()

func _tick_building(delta: float) -> void:
	var dist := global_position.distance_to(_build_target)
	if dist > 0.8:
		var dir := (_build_target - global_position).normalized()
		dir.y = 0.0
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_play_anim("Walk")
		_look_dir(dir)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		_play_anim("Wave")
		_build_wait -= delta
		if _build_wait <= 0.0:
			_place_fence_at(_build_target)
			fences_built += 1
			_state = State.WANDER
			_play_anim("Idle")
	move_and_slide()

func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(2.0, WANDER_RADIUS)
	_target_pos = _home_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _look_at_player() -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	var ld: Vector3 = _player_ref.global_position - global_position
	ld.y = 0.0
	_look_dir(ld)

func _look_dir(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	look_at(global_position + dir, Vector3.UP)

# ── Fence ─────────────────────────────────────────────────────────────────────

func _begin_build_next_fence() -> void:
	if fences_built >= FENCE_POSITIONS.size():
		return
	_build_target = FENCE_POSITIONS[fences_built]
	_build_wait   = 2.5
	_state = State.BUILDING

func _place_fence_at(pos: Vector3) -> void:
	const WALL_SCENE := "res://scenes/objects/WoodWall3D.tscn"
	var packed = load(WALL_SCENE)
	var fence: Node3D
	if packed:
		fence = packed.instantiate()
	else:
		fence = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 1.0, 0.15)
		(fence as MeshInstance3D).mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.28, 0.1)
		(fence as MeshInstance3D).material_override = mat
	fence.global_position = pos
	var to_centre := (Vector3(238.0, pos.y, -13.0) - pos).normalized()
	if to_centre.length_squared() > 0.01:
		fence.look_at(pos + to_centre, Vector3.UP)
	get_tree().root.add_child(fence)

# ── Interaction ───────────────────────────────────────────────────────────────

func interact(player: Node) -> void:
	if _dialogue_canvas != null:
		return
	if player != null and is_instance_valid(player):
		var ld := player.global_position - global_position
		ld.y = 0.0
		_look_dir(ld)
	if player and player.has_method("set"):
		player.set("_input_blocked", true)

	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(480, 220)
	panel.position = Vector2(-240, -240)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "Itachi" + ("  \U0001F480 (Dead)" if is_dead else "  (Farmer)")
	name_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.5, 0.5) if is_dead else Color(1.0, 0.85, 0.3))
	name_lbl.add_theme_font_size_override("font_size", 17)
	vbox.add_child(name_lbl)

	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 18)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [E]"
	close_btn.pressed.connect(_close_dialogue)
	btn_row.add_child(close_btn)

	if is_dead:
		msg.text = "Itachi is dead. Revive him with %d souls, or buy his house for %d gold." % [REVIVE_SOULS, HOUSE_COST]
		if not house_purchased:
			var buy_btn := Button.new()
			var gold: int = player.inventory.get("gold", 0) if player else 0
			buy_btn.text = "Buy House (%d Gold)  [have %d]" % [HOUSE_COST, gold]
			buy_btn.disabled = (gold < HOUSE_COST)
			buy_btn.pressed.connect(_buy_house.bind(player))
			btn_row.add_child(buy_btn)
		else:
			var owned_lbl := Label.new()
			owned_lbl.text = "  [House Owned]"
			btn_row.add_child(owned_lbl)

		var revive_btn := Button.new()
		var souls: int = player.inventory.get("souls", 0) if player else 0
		revive_btn.text = "Revive (%d Souls)  [have %d]" % [REVIVE_SOULS, souls]
		revive_btn.disabled = (souls < REVIVE_SOULS)
		revive_btn.pressed.connect(_revive.bind(player))
		btn_row.add_child(revive_btn)
	else:
		var wood: int = player.inventory.get("wood", 0) if player else 0
		var fences_left: int = FENCE_POSITIONS.size() - fences_built
		if fences_left <= 0:
			msg.text = "The fence is done! Thanks for helping me out, friend.\nI've got plenty of beef if you need it — just come back anytime."
		else:
			msg.text = "I need wood to build my fence. Give me %d wood and I'll give you some beef.\n%d fence piece%s left to build." % [
				WOOD_PER_FENCE, fences_left, "s" if fences_left != 1 else ""
			]
			var trade_btn := Button.new()
			trade_btn.text = "Give %d Wood  →  Get 1 Meat  [have %d wood]" % [WOOD_PER_FENCE, wood]
			trade_btn.disabled = (wood < WOOD_PER_FENCE)
			trade_btn.pressed.connect(_do_trade.bind(player, msg, trade_btn))
			btn_row.add_child(trade_btn)

	player.add_child(_dialogue_canvas)

func _do_trade(player: Node, _msg_lbl: Label, _trade_btn: Button) -> void:
	if not player or not is_instance_valid(player):
		return
	var wood: int = player.inventory.get("wood", 0)
	if wood < WOOD_PER_FENCE:
		return
	player.inventory["wood"] = wood - WOOD_PER_FENCE
	player.inventory_changed.emit("wood", player.inventory["wood"])
	if player.inventory.has("meat"):
		player.inventory["meat"] += MEAT_PER_TRADE
	else:
		player.inventory["meat"] = MEAT_PER_TRADE
	player.inventory_changed.emit("meat", player.inventory["meat"])
	_close_dialogue()
	_begin_build_next_fence()
	SaveManager.save_game()

func _buy_house(player: Node) -> void:
	if not player or not is_instance_valid(player):
		return
	var gold: int = player.inventory.get("gold", 0)
	if gold < HOUSE_COST:
		return
	player.inventory["gold"] = gold - HOUSE_COST
	player.inventory_changed.emit("gold", player.inventory["gold"])
	house_purchased = true
	_close_dialogue()
	SaveManager.save_game()

func _revive(player: Node) -> void:
	if not player or not is_instance_valid(player):
		return
	var souls: int = player.inventory.get("souls", 0)
	if souls < REVIVE_SOULS:
		return
	player.inventory["souls"] = souls - REVIVE_SOULS
	player.inventory_changed.emit("souls", player.inventory["souls"])
	is_dead = false
	hp = MAX_HP
	_state = State.WANDER
	if _name_label:
		_name_label.text = "Itachi"
		_name_label.modulate = Color(1.0, 0.85, 0.3)
	if _interact_label:
		_interact_label.text = "[E] Trade"
		_interact_label.modulate = Color(0.7, 1.0, 0.7)
	_update_hp_bar()
	_close_dialogue()
	SaveManager.save_game()

func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var parent: Node = _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if parent and parent.has_method("set"):
		parent.set("_input_blocked", false)

func _input(event: InputEvent) -> void:
	if _dialogue_canvas == null:
		return
	if event.is_action_pressed("ui_cancel") or \
			(event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_close_dialogue()

# ── Animation helper ──────────────────────────────────────────────────────────

func _play_anim(anim_name: String) -> void:
	if _anim_player == null or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name)
	elif anim_name != "Idle":
		_play_anim("Idle")

# ── Save / load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"hp":              hp,
		"is_dead":         is_dead,
		"fences_built":    fences_built,
		"house_purchased": house_purchased,
	}

func apply_save_data(d: Dictionary) -> void:
	hp              = int(d.get("hp",              MAX_HP))
	is_dead         = bool(d.get("is_dead",         false))
	fences_built    = int(d.get("fences_built",    0))
	house_purchased = bool(d.get("house_purchased", false))
	if is_dead:
		_state = State.DEAD
		if _name_label:
			_name_label.text = "Itachi  \U0001F480"
			_name_label.modulate = Color(0.5, 0.5, 0.5)
		if _interact_label:
			_interact_label.text = "[E] Revive / Buy House"
			_interact_label.modulate = Color(1.0, 0.4, 0.4)
	_update_hp_bar()
	for i: int in fences_built:
		_place_fence_at(FENCE_POSITIONS[i])
