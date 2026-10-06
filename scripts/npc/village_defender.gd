extends CharacterBody3D
# Rook - Village Defender
# Guards the village from wolves by day and all enemies by night.
# Each kill earns a level; level scales both HP and attack damage.
# Player can press E to toggle training mode - Rook follows and fights alongside.
# At level 100, unlocks a magic blast AoE attack.

const MODEL_PATH := "res://assets/models/characters/male_villager/male_villager.fbx"
const ANIM_DIR   := "res://assets/animations/npc/male_villager/"
const ANIM_FILES := {
	"Idle": "Idle.fbx",
	"Walk": "Standard Walk.fbx",
}

const NPC_NAME       := "Rook"
const INTERACT_RANGE := 4.0
const GRAVITY        := -20.0

@export var house_id:       String  = "cottage_2"
@export var guard_position: Vector3 = Vector3(198.0, 2.4, 89.0)

const MOVE_SPEED     := 3.8
const FOLLOW_DIST    := 3.5
const DETECT_RADIUS  := 18.0
const ATTACK_RANGE   := 2.2
const ATTACK_COOLDOWN := 1.4
const BLAST_COOLDOWN := 8.0
const BLAST_RANGE    := 12.0
const RESPAWN_DELAY  := 60.0

var defender_level: int = 1

func _base_health() -> int:
	return 60 + defender_level * 15

func _attack_damage() -> int:
	return 8 + defender_level * 3

enum State { GUARD, FOLLOW, COMBAT }
var _state: State = State.GUARD
var _training_mode: bool = false
var _current_hp: int = 0
var _attack_timer: float = 0.0
var _blast_timer:  float = 0.0
var _target_enemy: Node3D = null
var _is_night: bool = false
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""
var _player_ref: Node3D = null
var _dialogue_canvas: CanvasLayer = null
var _dnc: Node = null
var _dead: bool = false
var _respawn_timer: float = 0.0


func _ready() -> void:
	_current_hp = _base_health()
	if house_id != "" and not VillageManager.is_repaired(house_id):
		process_mode = Node.PROCESS_MODE_DISABLED
		visible = false
		VillageManager.register_dormant_npc(house_id, self)
		return
	_activate()


func _activate() -> void:
	add_to_group("interactable")
	add_to_group("village_defender")
	_spawn_model()
	_add_collision()
	_add_interact_label()
	_attach_sword()
	_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc == null:
		await get_tree().process_frame
		_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc != null:
		_dnc.night_started.connect(_on_night_started)
		_dnc.day_started.connect(_on_day_started)
		if _dnc.is_night():
			_on_night_started()
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D


# ---- Model/Animation -------------------------------------------------------

func _spawn_model() -> void:
	var packed = load(MODEL_PATH)
	if packed == null:
		push_warning("VillageDefender: model not found at " + MODEL_PATH)
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
	mat.albedo_color = Color(0.3, 0.35, 0.7)
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.9
	add_child(mesh_inst)


func _load_animations() -> void:
	var skeleton: Skeleton3D = _find_skeleton(self)
	if skeleton == null:
		push_warning("VillageDefender: no Skeleton3D found - animations disabled")
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
			push_warning("VillageDefender: animation not found: " + fpath)
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


func _play_anim(anim_name: String) -> void:
	if _anim_player == null or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name)
	elif anim_name != "Idle":
		_play_anim("Idle")


# ---- Setup helpers ---------------------------------------------------------

func _add_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	col.shape = cap
	col.position.y = 0.9
	add_child(col)


func _add_interact_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "[E] Talk to Rook"
	lbl.position = Vector3(0, 2.3, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.6, 0.85, 1.0)
	lbl.visible = false
	lbl.name = "InteractLabel"
	add_child(lbl)


func _attach_sword() -> void:
	var sword := MeshInstance3D.new()
	sword.name = "Sword"
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.65, 0.06)
	sword.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.82)
	mat.metallic = 0.9
	mat.roughness = 0.2
	sword.material_override = mat
	sword.position = Vector3(0.28, 0.85, 0.0)
	add_child(sword)


# ---- Day / Night -----------------------------------------------------------

func _on_night_started() -> void:
	_is_night = true

func _on_day_started() -> void:
	_is_night = false
	if _state == State.COMBAT:
		_state = State.GUARD if not _training_mode else State.FOLLOW
	_target_enemy = null


# ---- Main physics loop -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D

	_update_interact_label()
	_attack_timer -= delta
	_blast_timer -= delta

	match _state:
		State.GUARD:
			_state_guard(delta)
		State.FOLLOW:
			_state_follow(delta)
		State.COMBAT:
			_state_combat(delta)

	move_and_slide()


func _state_guard(_delta: float) -> void:
	var enemy: Node3D = _scan_for_enemies()
	if enemy != null:
		_target_enemy = enemy
		_state = State.COMBAT
		return
	var dist: float = global_position.distance_to(guard_position)
	if dist > 1.0:
		_move_toward(guard_position, MOVE_SPEED)
		_play_anim("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")


func _state_follow(_delta: float) -> void:
	if _player_ref == null:
		_state = State.GUARD
		return
	var enemy: Node3D = _scan_for_enemies()
	if enemy != null:
		_target_enemy = enemy
		_state = State.COMBAT
		return
	var dist: float = global_position.distance_to(_player_ref.global_position)
	if dist > FOLLOW_DIST:
		_move_toward(_player_ref.global_position, MOVE_SPEED)
		_play_anim("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")


func _state_combat(_delta: float) -> void:
	if not is_instance_valid(_target_enemy):
		_target_enemy = _scan_for_enemies()
		if _target_enemy == null:
			_state = State.FOLLOW if _training_mode else State.GUARD
			return

	var dist: float = global_position.distance_to(_target_enemy.global_position)
	var ld: Vector3 = _target_enemy.global_position - global_position
	ld.y = 0.0
	if ld.length() > 0.01:
		look_at(global_position + ld, Vector3.UP)

	if dist > ATTACK_RANGE:
		_move_toward(_target_enemy.global_position, MOVE_SPEED)
		_play_anim("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")
		if _attack_timer <= 0.0:
			_sword_strike()
		if defender_level >= 100 and _blast_timer <= 0.0:
			_fire_magic_blast()


# ---- Combat ----------------------------------------------------------------

func _scan_for_enemies() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = DETECT_RADIUS
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if not e is Node3D:
			continue
		if _is_night == false and not e.is_in_group("wolf"):
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e as Node3D
	return nearest


func _sword_strike() -> void:
	_attack_timer = ATTACK_COOLDOWN
	if not is_instance_valid(_target_enemy):
		return
	if _target_enemy.has_method("take_damage"):
		_target_enemy.take_damage(_attack_damage())
	if not is_instance_valid(_target_enemy):
		_on_kill()


func _on_kill() -> void:
	defender_level += 1
	_current_hp = mini(_current_hp + 20, _base_health())
	_target_enemy = null
	_show_level_up_text()
	if defender_level == 100:
		_announce_blast_unlock()


func _show_level_up_text() -> void:
	var lbl := Label3D.new()
	lbl.text = "Level Up! Lv." + str(defender_level)
	lbl.position = Vector3(0, 2.6, 0)
	lbl.font_size = 24
	lbl.modulate = Color(1.0, 0.85, 0.2)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", Vector3(0, 3.4, 0), 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)


func _announce_blast_unlock() -> void:
	var lbl := Label3D.new()
	lbl.text = "Magic Blast Unlocked!"
	lbl.position = Vector3(0, 3.0, 0)
	lbl.font_size = 28
	lbl.modulate = Color(0.5, 0.5, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", Vector3(0, 4.2, 0), 2.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(lbl.queue_free)


func _fire_magic_blast() -> void:
	_blast_timer = BLAST_COOLDOWN
	var blast_damage: int = 30 + defender_level * 2
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if not e is Node3D:
			continue
		var d: float = global_position.distance_to((e as Node3D).global_position)
		if d <= BLAST_RANGE:
			if e.has_method("take_damage"):
				e.take_damage(blast_damage)
	_magic_blast_vfx()


func _magic_blast_vfx() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.4, 1.0)
	light.omni_range = 12.0
	light.light_energy = 3.0
	light.position = Vector3(0, 1.0, 0)
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.8)
	tw.tween_callback(light.queue_free)


# ---- Death and respawn -----------------------------------------------------

func take_damage(amount: int) -> void:
	if _dead:
		return
	_current_hp -= amount
	if _current_hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	_respawn_timer = RESPAWN_DELAY
	visible = false
	_state = State.GUARD
	_target_enemy = null
	_training_mode = false


func _respawn() -> void:
	_dead = false
	_current_hp = _base_health()
	global_position = guard_position
	visible = true


# ---- Interaction -----------------------------------------------------------

func _update_interact_label() -> void:
	var lbl: Label3D = get_node_or_null("InteractLabel")
	if lbl == null:
		return
	if _player_ref == null:
		lbl.visible = false
		return
	var dist: float = global_position.distance_to(_player_ref.global_position)
	lbl.visible = dist < INTERACT_RANGE + 2.0 and not _dead


func _input(event: InputEvent) -> void:
	if _dialogue_canvas == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_dialogue()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_close_dialogue()


func interact(player: Node) -> void:
	if _dead or _dialogue_canvas != null:
		return
	if player != null:
		var ld: Vector3 = (player.global_position as Vector3) - global_position
		ld.y = 0.0
		if ld.length() > 0.01:
			look_at(global_position + ld, Vector3.UP)
	if player and player.has_method("set"):
		player.set("_input_blocked", true)

	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(480, 230)
	panel.position = Vector2(-240, -250)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "Rook  - Village Defender"
	name_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	var mode_str: String = "TRAINING" if _training_mode else "GUARD"
	var blast_str: String = "  |  Blast: UNLOCKED" if defender_level >= 100 else ""
	stats_lbl.text = "Level %d  |  HP %d/%d  |  ATK %d  |  Mode: %s%s" % [
		defender_level, _current_hp, _base_health(), _attack_damage(), mode_str, blast_str
	]
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(stats_lbl)

	var msg_lbl := Label.new()
	if _training_mode:
		msg_lbl.text = "I'll fight by your side, friend. Ready to protect the village."
	else:
		msg_lbl.text = "I guard this village with my life. Need me to train alongside you?"
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var train_btn := Button.new()
	if _training_mode:
		train_btn.text = "Stop Training"
	else:
		train_btn.text = "Train Together"
	train_btn.pressed.connect(_toggle_training.bind(player))
	hbox.add_child(train_btn)

	var close_btn := Button.new()
	close_btn.text = "Leave  [E]"
	close_btn.pressed.connect(_close_dialogue)
	hbox.add_child(close_btn)

	player.add_child(_dialogue_canvas)


func _toggle_training(player: Node) -> void:
	_training_mode = not _training_mode
	if _training_mode:
		_state = State.FOLLOW
	else:
		_state = State.GUARD
		_target_enemy = null
	_close_dialogue()
	if player and player.has_method("set"):
		player.set("_input_blocked", false)


func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var parent: Node = _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if parent and parent.has_method("set"):
		parent.set("_input_blocked", false)


# ---- VillageManager integration --------------------------------------------

func begin_walk_in() -> void:
	_current_hp = _base_health()
	add_to_group("interactable")
	add_to_group("village_defender")
	_spawn_model()
	_add_collision()
	_add_interact_label()
	_attach_sword()
	global_position = guard_position + Vector3(0, 0, 5)
	if _dnc == null:
		_dnc = get_tree().get_first_node_in_group("day_night")
		if _dnc != null:
			_dnc.night_started.connect(_on_night_started)
			_dnc.day_started.connect(_on_day_started)


func _move_toward(target: Vector3, speed: float) -> void:
	var dir: Vector3 = (target - global_position).normalized()
	dir.y = 0.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP)
