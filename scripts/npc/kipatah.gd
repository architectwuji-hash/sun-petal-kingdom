extends CharacterBody3D
## Kipatah — Gomushi's magic companion.
## Follows the player, auto-attacks enemies, and obeys player commands.

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
const ANIM_DIR: String = "res://assets/animations/npc/kipatah/"
const ANIM_CLIPS: Dictionary = {
	"Idle":        "Idle.fbx",
	"Walk":        "Walk.fbx",
	"Run":         "Run.fbx",
	"SpellCast":   "SpellCast.fbx",
	"MagicAttack": "MagicAttack.fbx",
	"WideSpell":   "WideSpell.fbx",
	"Heal":        "Heal.fbx",
}

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/npc/MagicProjectile.tscn")
const AI_SCENE: PackedScene = preload("res://scenes/npc/KipatahAI.tscn")
const VFX_CAST: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")
const VFX_AREA: PackedScene = preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const WIDE_SPELL_RADIUS: float = 3.5
const WIDE_SPELL_DAMAGE: int = 14

const GRAVITY: float = 20.0
const FOLLOW_DIST: float = 3.8
const RUN_THRESHOLD: float = 4.5
const ATTACK_RANGE: float = 14.0
const ATTACK_COOLDOWN: float = 2.2
const MOVE_SPEED: float = 3.5

const COMMAND_RANGE: float = 3.5       # How close player must be to open command menu
const ROAM_RADIUS: float = 18.0        # Max distance from player when roaming
const ROAM_CHANGE_TIME: float = 8.0   # Seconds before picking a new roam target

# ── MODE ENUM ─────────────────────────────────────────────────────────────────
enum KipatahMode { FOLLOW, GUARD, FREE_ROAM, HUNT_TOTTIES }

# ── STATE ─────────────────────────────────────────────────────────────────────
var _player: CharacterBody3D = null
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _can_attack: bool = true
var _casting: bool = false
var _nav: NavigationAgent3D = null

var _mode: KipatahMode = KipatahMode.FOLLOW
var _guard_pos: Vector3 = Vector3.ZERO
var _roam_target: Vector3 = Vector3.ZERO
var _roam_timer: float = 0.0

var _player_nearby: bool = false   # within COMMAND_RANGE
var _interact_cooldown: float = 0.0
var _cmd_menu_open: bool = false
var _cmd_options: Array[Array] = []
var _cmd_layer: CanvasLayer = null
var _hint_label: Label = null      # "Press E — Commands" shown near Kipatah

# Hunt Totties state
var _ki_inventory: Dictionary = {}   # Kipatah own inventory {"tottie": int, ...}
var _hunt_target: Node3D = null       # Current tottie being hunted
var _hunt_session_count: int = 0       # Totties hunted this session (resets on new hunt command)
var _hunt_search_target: Vector3 = Vector3.ZERO  # Where she is walking to look for totties
var _hunt_search_timer: float = 0.0              # How long until she picks a new search spot
const HUNT_SEARCH_RADIUS: float = 55.0           # How far from player she roams to search
const HUNT_SEARCH_CHANGE_TIME: float = 6.0       # Seconds at each search spot before moving on

# ── KIPATAH LEVELING ──────────────────────────────────────────────────────────
signal kip_level_changed(new_level: int, xp: int, xp_required: int)

var kip_level: int = 1
var kip_xp: int = 0
var _kip_level_label: Label3D = null


## ── Tree Running ──────────────────────────────────────────────────────────────
var _tree_jump_target  : StaticBody3D = null
var _tree_jump_pending : bool         = false
var _tree_jump_timer   : float        = 0.0
const KIPATAH_TREE_JUMP_DELAY : float = 0.8   ## seconds behind player
const KIPATAH_JUMP_SPEED_H    : float = 12.0
const KIPATAH_JUMP_SPEED_V    : float = 10.0

func _ready() -> void:
	add_to_group("companion")
	add_to_group("kipatah")
	var ai_node: Node = AI_SCENE.instantiate()
	ai_node.name = "KipatahAI"
	add_child(ai_node)
	ai_node.add_to_group("kipatah_ai")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	# Hook into player's tree running so Kipatah follows
	if _player:
		var tree_run_node : Node = _player.get_node_or_null("TreeRunning")
		if tree_run_node and tree_run_node.has_signal("jumped_to_tree"):
			tree_run_node.jumped_to_tree.connect(_on_player_jumped_to_tree)

	_nav = NavigationAgent3D.new()
	_nav.name = "NavigationAgent3D"
	add_child(_nav)

	_skeleton = _find_skeleton(self)
	_anim = _find_anim_player(self)
	if _anim == null and _skeleton != null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_skeleton.get_parent().add_child(_anim)

	if _anim != null and _skeleton != null:
		print("[K-DBG] skel=", _skeleton.name, " bones=", _skeleton.get_bone_count(), " anim_in_tree=", _anim.is_inside_tree())
		if _skeleton.get_bone_count() > 0:
			for _bi in min(3, _skeleton.get_bone_count()):
				print("  bone[",_bi,"]=", _skeleton.get_bone_name(_bi))
		_strip_mixamo_prefix()
		_load_animations()
	else:
		print("[K-DBG] MISSING: anim=", _anim, " skel=", _skeleton)
		var _cm := get_node_or_null("CharacterModel")
		if _cm:
			_dump_tree(_cm, 0)
		else:
			print("[K-DBG] CharacterModel not found")

	_build_command_ui()
	_spawn_kip_level_badge()
	_play("Idle")


func _physics_process(delta: float) -> void:
	# ── Tree running follow ───────────────────────────────────────────────────
	if _tree_jump_pending:
		_tree_jump_timer -= delta
		if _tree_jump_timer <= 0.0:
			_tree_jump_pending = false
			if is_instance_valid(_tree_jump_target):
				var dir : Vector3 = (_tree_jump_target.global_position - global_position).normalized()
				velocity   = dir * KIPATAH_JUMP_SPEED_H
				velocity.y = KIPATAH_JUMP_SPEED_V
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _player == null:
		move_and_slide()
		return

	# ── Proximity check for command menu hint ───────────────────────────────
	var dist_to_player: float = global_position.distance_to(_player.global_position)
	_player_nearby = dist_to_player <= COMMAND_RANGE
	if _hint_label != null:
		_hint_label.visible = _player_nearby and not _cmd_menu_open

	# ── E key: toggle command menu ──────────────────────────────────────────
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta
	elif _player_nearby and Input.is_key_pressed(KEY_K):
		_interact_cooldown = 0.4
		if _cmd_menu_open:
			_close_command_menu()
		else:
			_open_command_menu()
		move_and_slide()
		return

	if _cmd_menu_open:
		# Number keys select command options
		for i in range(_cmd_options.size()):
			var key_code: int = int(KEY_1) + i
			if Input.is_key_pressed(key_code as Key):
				var opt: Array = _cmd_options[i] as Array
				if opt[1] == -1:
					# Special: Give Tottie
					_give_tottie_to_player()
				else:
					set_mode(opt[1] as int as KipatahMode)
				_close_command_menu()
				break
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 4 * delta)
		move_and_slide()
		return

	# ── Combat: attack nearby enemies (all modes) ───────────────────────────
	if not _casting:
		var enemy := _find_nearest_enemy()
		if enemy != null and _can_attack:
			_start_cast(enemy)
			move_and_slide()
			return

	if _casting:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 4 * delta)
		move_and_slide()
		return

	# ── Mode-specific movement ──────────────────────────────────────────────
	match _mode:
		KipatahMode.FOLLOW:
			_follow_player(delta)
		KipatahMode.GUARD:
			_guard_behavior(delta)
		KipatahMode.FREE_ROAM:
			_free_roam_behavior(delta)
		KipatahMode.HUNT_TOTTIES:
			_hunt_tottie_behavior(delta)

	move_and_slide()


# ── MODES ─────────────────────────────────────────────────────────────────────

func set_mode(new_mode: KipatahMode) -> void:
	_mode = new_mode
	match new_mode:
		KipatahMode.GUARD:
			_guard_pos = global_position
			print("[Kipatah] Guard mode — holding at ", _guard_pos)
		KipatahMode.FREE_ROAM:
			_pick_roam_target()
			print("[Kipatah] Free roam mode")
		KipatahMode.FOLLOW:
			print("[Kipatah] Follow mode")
		KipatahMode.HUNT_TOTTIES:
			_hunt_target = null
			_hunt_session_count = 0
			print("[Kipatah] Hunt Totties mode — on the prowl!")
	_close_command_menu()


func _follow_player(delta: float) -> void:
	var dist: float = global_position.distance_to(_player.global_position)

	if dist < FOLLOW_DIST:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 4 * delta)
		_play("Idle")
		return

	var behind: Vector3 = _player.global_position - _player.global_transform.basis.z * FOLLOW_DIST
	behind += _player.global_transform.basis.x * 0.8

	# Move toward player — prefer nav mesh, fall back to direct if nav isn't helping
	var move_target: Vector3 = behind
	if _nav != null:
		_nav.target_position = behind
		var nav_next: Vector3 = _nav.get_next_path_position()
		var to_nav: Vector3 = nav_next - global_position
		to_nav.y = 0.0
		# Only trust nav if it's pointing meaningfully toward the destination
		var to_dest: Vector3 = behind - global_position
		to_dest.y = 0.0
		if to_nav.length_squared() > 0.04 and to_nav.dot(to_dest) > 0.0:
			move_target = nav_next
	var to_next: Vector3 = move_target - global_position
	to_next.y = 0.0
	if to_next.length_squared() > 0.04:
		var dir: Vector3 = to_next.normalized()
		var spd: float = MOVE_SPEED * (1.6 if dist > RUN_THRESHOLD else 1.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		rotation.y = atan2(dir.x, dir.z)

	if dist > RUN_THRESHOLD:
		_play("Run")
	else:
		_play("Walk")


func _guard_behavior(delta: float) -> void:
	# Stay put at _guard_pos; face player if nearby, else idle
	var to_guard: Vector3 = _guard_pos - global_position
	to_guard.y = 0.0
	var dist: float = to_guard.length()

	if dist > 1.2:
		# Walk back to guard position
		var dir: Vector3 = to_guard.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		rotation.y = atan2(dir.x, dir.z)
		_play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 4 * delta)
		# Face player
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			rotation.y = atan2(to_player.x, to_player.z)
		_play("Idle")


func _free_roam_behavior(delta: float) -> void:
	# Wander near player; pick new target every ROAM_CHANGE_TIME seconds
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_pick_roam_target()

	var to_target: Vector3 = _roam_target - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	if dist > 1.0:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * (MOVE_SPEED * 0.75)
		velocity.z = dir.z * (MOVE_SPEED * 0.75)
		rotation.y = atan2(dir.x, dir.z)
		_play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 4 * delta)
		_play("Idle")
		_roam_timer = randf_range(2.0, ROAM_CHANGE_TIME)


func _pick_roam_target() -> void:
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(4.0, ROAM_RADIUS)
	# Pick from her current spot so she genuinely wanders, not just circles the player
	var candidate: Vector3 = global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	# But don't let her drift more than ROAM_RADIUS from the player
	if _player != null:
		var to_player: Vector3 = _player.global_position - candidate
		to_player.y = 0.0
		if to_player.length() > ROAM_RADIUS * 1.5:
			candidate = _player.global_position + to_player.normalized() * -ROAM_RADIUS
	_roam_target = candidate
	_roam_timer = randf_range(4.0, ROAM_CHANGE_TIME)


# ── COMMAND MENU UI ───────────────────────────────────────────────────────────

func _build_command_ui() -> void:
	# CanvasLayer lives as child of Kipatah so it's auto-freed
	_cmd_layer = CanvasLayer.new()
	_cmd_layer.layer = 5
	add_child(_cmd_layer)

	# Hint label (shown when player is nearby but menu isn't open)
	_hint_label = Label.new()
	_hint_label.text = "Press K — Kipatah commands"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position = Vector2(-120, -80)
	_hint_label.size = Vector2(240, 30)
	_hint_label.visible = false
	_cmd_layer.add_child(_hint_label)


func _open_command_menu() -> void:
	_cmd_menu_open = true
	_hint_label.visible = false
	# Block all player input while menu is open
	if _player and _player.has_method("set_input_blocked"):
		_player.set_input_blocked(true)

	# Build the options list (stored so _physics_process can read index)
	_cmd_options = [
		["📣  Follow Me",    KipatahMode.FOLLOW],
		["🛡  Guard",        KipatahMode.GUARD],
		["🌸  Free Roam",    KipatahMode.FREE_ROAM],
		["🍗  Hunt Totties", KipatahMode.HUNT_TOTTIES],
	]
	var tottie_count: int = _ki_inventory.get("tottie", 0)
	if tottie_count > 0:
		_cmd_options.append(["Give Tottie (%d)" % tottie_count, -1])

	# Container panel
	var panel := PanelContainer.new()
	panel.name = "KipatahCmdPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-120, -220)
	panel.size = Vector2(240, 40 + _cmd_options.size() * 28)
	_cmd_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "✦  Kipatah  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Numbered option labels
	for i in range(_cmd_options.size()):
		var opt: Array = _cmd_options[i] as Array
		var lbl := Label.new()
		var is_active: bool = (i < 4) and (int(_mode) == int(opt[1]))
		var suffix: String = "  ✓" if is_active else ""
		lbl.text = "%d.  %s%s" % [i + 1, str(opt[0]), suffix]
		lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(lbl)

	# Hint at bottom
	var hint := Label.new()
	hint.text = "[ K ] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(hint)


func _close_command_menu() -> void:
	_cmd_menu_open = false
	# Restore player input
	if _player and _player.has_method("set_input_blocked"):
		_player.set_input_blocked(false)
	var panel := _cmd_layer.get_node_or_null("KipatahCmdPanel")
	if panel != null:
		panel.queue_free()


# ── HUNT TOTTIES ─────────────────────────────────────────────────────────────

func _hunt_tottie_behavior(delta: float) -> void:
	# Phase 1: Do we have a live tottie in range to chase?
	if not is_instance_valid(_hunt_target):
		_hunt_target = _find_nearest_tottie()

	if is_instance_valid(_hunt_target):
		# Chase and harvest
		var dist: float = global_position.distance_to(_hunt_target.global_position)
		if dist > 1.5:
			_move_toward_target(_hunt_target.global_position, delta)
		else:
			if _hunt_target.has_method("harvest_by_kipatah"):
				if not _hunt_target.is_connected("tottie_harvested", _on_tottie_harvested):
					_hunt_target.connect("tottie_harvested", _on_tottie_harvested, CONNECT_ONE_SHOT)
				_hunt_target.harvest_by_kipatah()
			_hunt_target = null
		return

	# Phase 2: No tottie spotted yet — roam the forest searching
	_hunt_search_timer -= delta
	if _hunt_search_timer <= 0.0 or global_position.distance_to(_hunt_search_target) < 2.5:
		_pick_hunt_search_spot()

	_move_toward_target(_hunt_search_target, delta)


func _move_toward_target(target_pos: Vector3, _delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	var dist: float = (target_pos - global_position).length()
	var spd: float = MOVE_SPEED * (1.5 if dist > RUN_THRESHOLD else 1.0)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	rotation.y = atan2(dir.x, dir.z)
	if dist > RUN_THRESHOLD:
		_play("Run")
	else:
		_play("Walk")


func _on_tottie_harvested(_tottie: Node3D) -> void:
	_ki_inventory["tottie"] = _ki_inventory.get("tottie", 0) + 1
	_hunt_session_count += 1
	print("[Kipatah] Harvested a Tottie! I now have ", _ki_inventory["tottie"], " (", _hunt_session_count, "/3 this hunt).")
	_hunt_target = null
	if _hunt_session_count >= 3:
		print("[Kipatah] Got 3 Totties — returning to follow!")
		set_mode(KipatahMode.FOLLOW)


func _find_nearest_tottie() -> Node3D:
	var best: Node3D = null
	var best_dist: float = 200.0   # Search the whole world — she is hunting!
	for t in get_tree().get_nodes_in_group("tottie"):
		if not is_instance_valid(t):
			continue
		if t.get("_dead") == true:
			continue
		var d: float = global_position.distance_to((t as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = t as Node3D
	return best


func _pick_hunt_search_spot() -> void:
	# Pick a random spot in the forest to walk to while searching
	var player_pos: Vector3 = _player.global_position if is_instance_valid(_player) else global_position
	var angle: float = randf() * TAU
	var radius: float = randf_range(20.0, HUNT_SEARCH_RADIUS)
	_hunt_search_target = player_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_hunt_search_timer = randf_range(HUNT_SEARCH_CHANGE_TIME * 0.7, HUNT_SEARCH_CHANGE_TIME)
	print("[Kipatah] Hunting — searching at ", _hunt_search_target)


func _give_tottie_to_player() -> void:
	var count: int = _ki_inventory.get("tottie", 0)
	if count <= 0:
		print("[Kipatah] I don't have any Totties to give.")
		_close_command_menu()
		return
	var player: Node3D = _player as Node3D
	if player != null and player.has_method("add_item"):
		player.add_item("tottie")
	_ki_inventory["tottie"] = count - 1
	print("[Kipatah] Gave you a Tottie! I have ", _ki_inventory["tottie"], " left.")
	_close_command_menu()


# ── COMBAT ────────────────────────────────────────────────────────────────────

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist: float = ATTACK_RANGE
	for body in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(body):
			continue
		var d: float = global_position.distance_to((body as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = body as Node3D
	if best != null:
		var player_dist: float = _player.global_position.distance_to(best.global_position)
		if player_dist < ATTACK_RANGE:
			return best
	return null


func _start_cast(enemy: Node3D) -> void:
	_casting = true
	_can_attack = false

	var dir: Vector3 = enemy.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		rotation.y = atan2(dir.x, dir.z)

	var anims: Array[String] = ["SpellCast", "MagicAttack", "WideSpell"]
	var pick: String = anims[randi() % anims.size()]
	_play(pick)

	_spawn_cast_flare(Color(1, 0.8, 0.2), Color(1, 0.4, 0.1))

	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(enemy):
		if pick == "WideSpell":
			_spawn_fire_area(enemy.global_position)
		else:
			_fire_projectile(enemy)

	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	_casting = false
	_can_attack = true


func _fire_projectile(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var proj: Node3D = PROJECTILE_SCENE.instantiate() as Node3D
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.4, 0)
	if "target" in proj:
		proj.set("target", target)
	if "damage" in proj:
		proj.set("damage", _kip_proj_damage())
	if "fired_by" in proj:
		proj.set("fired_by", self)


# ── VFX ───────────────────────────────────────────────────────────────────────

func _hand_position() -> Vector3:
	if _skeleton != null:
		for bn in ["RightHand", "mixamorig_RightHand", "mixamorig:RightHand"]:
			var idx: int = _skeleton.find_bone(bn)
			if idx >= 0:
				return (_skeleton.global_transform * _skeleton.get_bone_global_pose(idx)).origin
	return global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.5


func _spawn_cast_flare(primary: Color, secondary: Color) -> void:
	var fx := VFX_CAST.instantiate() as Node3D
	get_parent().add_child(fx)
	fx.global_position = _hand_position()
	fx.scale = Vector3.ONE * 0.6
	fx.set("one_shot", true)
	fx.set("primary_color", primary)
	fx.set("secondary_color", secondary)
	fx.call("play")
	get_tree().create_timer(1.2).timeout.connect(fx.queue_free)


func _spawn_fire_area(center: Vector3) -> void:
	var fx := VFX_AREA.instantiate() as Node3D
	get_parent().add_child(fx)
	fx.global_position = Vector3(center.x, center.y + 0.05, center.z)
	fx.scale = Vector3.ONE * (WIDE_SPELL_RADIUS / 1.4)
	for _pulse in 2:
		for body in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(body) and (body as Node3D).global_position.distance_to(center) <= WIDE_SPELL_RADIUS:
				if body.has_method("take_damage"):
					body.take_damage(_kip_wide_damage(), self)
		await get_tree().create_timer(0.7).timeout
	if is_instance_valid(fx):
		fx.set("emitting", false)
		get_tree().create_timer(0.8).timeout.connect(fx.queue_free)


# ── ANIMATION LOADING ─────────────────────────────────────────────────────────

func _strip_mixamo_prefix() -> void:
	if _skeleton == null:
		return
	var stripped := false
	for i: int in _skeleton.get_bone_count():
		var bname: String = _skeleton.get_bone_name(i)
		if bname.begins_with("mixamorig:") or bname.begins_with("mixamorig_"):
			_skeleton.set_bone_name(i, bname.substr(10))
			stripped = true
	if stripped:
		_fix_skin_bind_names(self)
		print("[Kipatah] Stripped mixamorig prefix from bones")


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


func _load_animations() -> void:
	if _anim == null or _skeleton == null:
		return
	# Stop any autoplay that fired before our _ready() ran
	_anim.stop()
	_anim.active = false
	for _ln in _anim.get_animation_library_list():
		_anim.remove_animation_library(_ln)
	var dst_lib: AnimationLibrary = AnimationLibrary.new()
	_anim.add_animation_library("", dst_lib)
	_anim.active = true
	var anim_root: Node = _anim.get_node(_anim.root_node)
	var skel_rel: NodePath = anim_root.get_path_to(_skeleton)
	print("[K-DBG] anim_root=", anim_root.name, " skel_rel=", skel_rel)

	for key in ANIM_CLIPS.keys():
		var clip_name: String = str(key)
		var path: String = ANIM_DIR + str(ANIM_CLIPS[key])
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var scene: Node = packed.instantiate()
		var src_player: AnimationPlayer = _find_anim_player(scene)
		if src_player != null:
			for lib_name in src_player.get_animation_library_list():
				var src_lib: AnimationLibrary = src_player.get_animation_library(lib_name)
				for anim_name in src_lib.get_animation_list():
					var anim_str: String = str(anim_name)
					if anim_str == "RESET":
						continue
					var target_name: String = clip_name
					var _src_anim: Animation = src_lib.get_animation(anim_str)
					if _src_anim == null:
						continue
					var anim: Animation = _src_anim.duplicate(true)
					if dst_lib.has_animation(target_name):
						dst_lib.remove_animation(target_name)
					for i: int in anim.get_track_count():
						var subpath: String = anim.track_get_path(i).get_concatenated_subnames()
						if subpath.begins_with("mixamorig:") or subpath.begins_with("mixamorig_"):
							subpath = subpath.substr(10)
						anim.track_set_path(i, NodePath(str(skel_rel) + ":" + subpath))
					if target_name in ["Idle", "Walk", "Run"]:
						anim.loop_mode = Animation.LOOP_LINEAR
					dst_lib.add_animation(target_name, anim)
					var _ok := 0
					for _t: int in anim.get_track_count():
						if _skeleton.find_bone(anim.track_get_path(_t).get_concatenated_subnames()) >= 0:
							_ok += 1
					print("[K-DBG] Loaded anim: ", target_name, " tracks=", anim.get_track_count(), " bone_matches=", _ok, " first=", str(anim.track_get_path(0)) if anim.get_track_count() > 0 else "")
		scene.queue_free()


func _play(anim_name: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		if _anim.current_animation != anim_name or not _anim.is_playing():
			_anim.play(anim_name, 0.2)
	else:
		print("[K-DBG] anim '", anim_name, "' not found. Has: ", _anim.get_animation_list())


## Called by KipatahChatPanel when Kipatah's AI response contains a [DO: action] tag.
func perform_action(action_name: String) -> void:
	match action_name:
		"spell_cast":
			_play("SpellCast")
			_spawn_cast_flare(Color(1, 0.8, 0.2), Color(1, 0.4, 0.1))
		"heal":
			_play("Heal")
			_spawn_cast_flare(Color(0.6, 1.0, 0.5), Color(0.2, 0.8, 0.3))
			if _player != null and _player.has_method("heal"):
				_player.heal(15)
		"walk_to_player":
			if _player != null:
				var d := global_position.distance_to(_player.global_position)
				if d > 1.5:
					var dir := (_player.global_position - global_position).normalized()
					dir.y = 0.0
					rotation.y = atan2(dir.x, dir.z)
					_play("Walk")
		"look_around":
			var tween := create_tween()
			tween.tween_property(self, "rotation:y", rotation.y + TAU * 0.5, 1.2)
			_play("Idle")
		"wave":
			_play("Idle")
		"idle", _:
			_play("Idle")


# ── DEBUG HELPERS ─────────────────────────────────────────────────────────────

func _dump_tree(node: Node, depth: int) -> void:
	print("[K-TREE] ", "  ".repeat(depth), node.name, " [", node.get_class(), "]")
	for _dc in node.get_children(true):
		_dump_tree(_dc, depth + 1)

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

# ── KIPATAH LEVELING SYSTEM ──────────────────────────────────────────────────

## XP required to go from kip_level → kip_level+1.
func _kip_xp_required() -> int:
	return kip_level * kip_level * 8


## Projectile damage, scales with level: starts 14, +4 per level.
func _kip_proj_damage() -> int:
	return 14 + (kip_level - 1) * 4


## Wide-spell AOE damage per pulse, scales with level: starts 10, +3 per level.
func _kip_wide_damage() -> int:
	return 10 + (kip_level - 1) * 3


## Effective attack cooldown: starts 2.2 s, -0.08 per level, minimum 0.8 s.
func _kip_current_cooldown() -> float:
	return maxf(0.8, ATTACK_COOLDOWN - (kip_level - 1) * 0.08)


## Grant XP to Kipatah. Called by EnemyBase._grant_xp() when she lands the kill.
func kip_add_xp(amount: int) -> void:
	kip_xp += amount
	var required: int = _kip_xp_required()
	while kip_xp >= required:
		kip_xp -= required
		kip_level += 1
		_kip_on_level_up()
		required = _kip_xp_required()
	emit_signal("kip_level_changed", kip_level, kip_xp, required)


## Called once per level-up. Refreshes stats and plays visuals.
func _kip_on_level_up() -> void:
	_kip_level_label_update()
	_kip_level_up_flash()
	emit_signal("kip_level_changed", kip_level, kip_xp, _kip_xp_required())
	print("[Kipatah] Leveled up! Now Lv.", kip_level,
		" — proj dmg:", _kip_proj_damage(),
		" | wide dmg:", _kip_wide_damage(),
		" | cooldown:", _kip_current_cooldown())


## Creates a small floating Label3D above Kipatah showing her current level.
func _spawn_kip_level_badge() -> void:
	_kip_level_label = Label3D.new()
	_kip_level_label.name = "KipLevelBadge"
	_kip_level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_kip_level_label.no_depth_test = true
	_kip_level_label.font_size = 48
	_kip_level_label.modulate = Color(1.0, 0.85, 0.3)
	_kip_level_label.outline_size = 6
	_kip_level_label.outline_modulate = Color(0.1, 0.05, 0.0)
	add_child(_kip_level_label)
	_kip_level_label.position = Vector3(0.0, 2.4, 0.0)
	_kip_level_label_update()


func _kip_level_label_update() -> void:
	if _kip_level_label != null:
		_kip_level_label.text = "\u2736 Kip Lv." + str(kip_level)


## Cyan-gold burst flash when Kipatah gains a level.
func _kip_level_up_flash() -> void:
	var lbl := Label3D.new()
	lbl.text = "Lv." + str(kip_level) + " !"
	lbl.font_size = 72
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(0.4, 1.0, 0.9)
	lbl.outline_size = 8
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, 3.0, 0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.5, 0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.25)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 1.0, 0.9)
	glow.light_energy = 0.0
	glow.omni_range = 5.0
	add_child(glow)
	var ltw := create_tween()
	ltw.tween_property(glow, "light_energy", 8.0, 0.25)
	ltw.tween_property(glow, "light_energy", 0.0, 0.6)
	ltw.tween_callback(glow.queue_free)

# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"x":         global_position.x,
		"y":         global_position.y,
		"z":         global_position.z,
		"mode":      int(_mode),
		"kip_level": kip_level,
		"kip_xp":    kip_xp,
	}


func apply_save_data(d: Dictionary) -> void:
	global_position = Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 1.0)),
		float(d.get("z", 0.0))
	)
	_mode     = d.get("mode", KipatahMode.FOLLOW) as KipatahMode
	kip_level = int(d.get("kip_level", 1))
	kip_xp    = int(d.get("kip_xp",    0))
	_kip_level_label_update()
	emit_signal("kip_level_changed", kip_level, kip_xp, _kip_xp_required())

## ── Tree Running ──────────────────────────────────────────────────────────────

func _on_player_jumped_to_tree(platform: StaticBody3D) -> void:
	## Called when the player uses tree running to jump to a new platform.
	## Kipatah follows after a short delay so she stays in sync.
	if not is_instance_valid(platform):
		return
	_tree_jump_target  = platform
	_tree_jump_timer   = KIPATAH_TREE_JUMP_DELAY
	_tree_jump_pending = true
