extends CharacterBody3D

## Male Villager NPC — wanders Suji Village, waves at nearby player, says "Hi!" on interact.

const MODEL_PATH := "res://assets/models/characters/male_villager/male_villager.fbx"
const ANIM_DIR  := "res://assets/animations/npc/male_villager/"
const ANIM_FILES := {
	"Idle": "Idle.fbx",
	"Walk": "Standard Walk.fbx",
	"Wave": "Waving Gesture.fbx",
}

const WANDER_RADIUS   := 12.0
const MOVE_SPEED      := 2.2
const WAVE_DISTANCE   := 6.5
const INTERACT_RANGE  := 4.0
const GRAVITY         := -20.0
const WANDER_WAIT_MIN := 2.0
const WANDER_WAIT_MAX := 5.0

var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _target_pos: Vector3
var _home_pos: Vector3
var _wander_timer := 0.0
var _waving := false
var _player_ref: Node = null
var _dialogue_canvas: CanvasLayer = null

func _ready() -> void:
	add_to_group("interactable")
	_home_pos = global_position
	_target_pos = global_position
	_wander_timer = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	_spawn_model()
	_add_collision()
	_add_label()

func _spawn_model() -> void:
	var packed = load(MODEL_PATH)
	if packed == null:
		push_warning("MaleVillager: model not found at " + MODEL_PATH)
		_add_placeholder()
		return
	var model: Node3D = packed.instantiate()
	model.scale = Vector3(0.01, 0.01, 0.01)
	add_child(model)
	_load_animations()

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
	_anim_player = AnimationPlayer.new()
	add_child(_anim_player)
	var lib := AnimationLibrary.new()
	for anim_name in ANIM_FILES:
		var path: String = ANIM_DIR + ANIM_FILES[anim_name]
		var packed = load(path)
		if packed == null:
			push_warning("MaleVillager: animation not found: " + path)
			continue
		var anim_root: Node3D = packed.instantiate()
		var src_player: AnimationPlayer = _find_anim_player(anim_root)
		if src_player == null:
			anim_root.queue_free()
			continue
		for src_name in src_player.get_animation_list():
			if src_name == "RESET":
				continue
			var anim: Animation = src_player.get_animation(src_name).duplicate()
			for ti in range(anim.get_track_count()):
				anim.track_set_path(ti, str(anim.track_get_path(ti)).replace("mixamorig:", ""))
			if not lib.has_animation(anim_name):
				lib.add_animation(anim_name, anim)
		anim_root.queue_free()
	_anim_player.add_animation_library("", lib)
	_play_anim("Idle")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var r = _find_anim_player(child)
		if r:
			return r
	return null

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
	lbl.text = "[E] Talk"
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
			label.visible = dist < INTERACT_RANGE + 2.0
		if dist < WAVE_DISTANCE and not _waving:
			_waving = true
			_play_anim("Wave")
			var ld := (_player_ref.global_position - global_position)
			ld.y = 0.0
			if ld.length() > 0.01:
				look_at(global_position + ld, Vector3.UP)
		elif dist >= WAVE_DISTANCE and _waving:
			_waving = false
		if _waving:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
	else:
		if label:
			label.visible = false

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
	_target_pos = _home_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _play_anim(anim_name: String) -> void:
	if _anim_player == null or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_current_anim = anim_name
		_anim_player.play(anim_name)
	elif anim_name != "Idle":
		_play_anim("Idle")

func interact(player: Node) -> void:
	if _dialogue_canvas != null:
		return
	if player != null:
		var ld := (player.global_position - global_position)
		ld.y = 0.0
		if ld.length() > 0.01:
			look_at(global_position + ld, Vector3.UP)
	if player and player.has_method("set"):
		player.set("_input_blocked", true)

	_dialogue_canvas = CanvasLayer.new()
	_dialogue_canvas.layer = 15

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(420, 140)
	panel.position = Vector2(-210, -160)
	_dialogue_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "Villager"
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = "Hi!"
	msg_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(msg_lbl)

	var btn := Button.new()
	btn.text = "Close  [E]"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_close_dialogue)
	vbox.add_child(btn)

	player.add_child(_dialogue_canvas)

func _close_dialogue() -> void:
	if _dialogue_canvas == null:
		return
	var player: Node = _dialogue_canvas.get_parent()
	_dialogue_canvas.queue_free()
	_dialogue_canvas = null
	if player and player.has_method("set"):
		player.set("_input_blocked", false)
