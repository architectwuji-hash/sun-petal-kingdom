extends CharacterBody3D
class_name EnemyBase

signal died(enemy: EnemyBase)

## Stats — tweak in the Inspector for each enemy variant.
@export var enemy_name: String = "Enemy"
@export var enemy_level: int = 1
@export var move_speed: float = 3.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 15.0
@export var lose_range: float = 22.0       ## Chase drops off beyond this distance
@export var hearing_range: float = 20.0    ## Radius for made_noise response
@export var hit_damage: int = 10
@export var wander_radius: float = 8.0
@export var idle_time_min: float = 1.0
@export var idle_time_max: float = 3.5

## When true the enemy keeps its own textures; only flashes white on hit.
## When false a flat tint_color is applied (good for untextured/kenney models).
@export var preserve_textures: bool = false
@export var tint_color: Color = Color(0.75, 0.1, 0.1)

const GRAVITY := 20.0
const DamageNumberScene := preload("res://scenes/ui/DamageNumber.tscn")
## Same Universal Animation Library the player uses — bone names match all
## Quaternius packs so animations retarget onto Imp / Puglin automatically.
const UAL_SCENE := preload("res://assets/animations/quaternius/UAL1_Standard.glb")

## SEARCH added: enemy moves to last-known position when it loses sight.
enum State { IDLE, WANDER, CHASE, SEARCH, ATTACK }

var max_health: int = 0
var health: int = 0
var _player: CharacterBody3D = null
var _can_attack := true
var _dying := false
var _saved_mats: Dictionary = {}

var _state: State = State.IDLE
var _spawn_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null

## Doctor Quack AI additions — auto-created in _ready() if absent from scene.
var _nav_agent: NavigationAgent3D = null
var _vision_ray: RayCast3D = null
var _last_known_pos: Vector3 = Vector3.ZERO
var _vision_cooldown: float = 0.0
const _VISION_INTERVAL := 0.15


func _ready() -> void:
	max_health = enemy_level * 20
	health = max_health
	_spawn_position = global_position
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# ── NavigationAgent3D — create dynamically if the scene doesn't have one.
	_nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _nav_agent == null:
		_nav_agent = NavigationAgent3D.new()
		_nav_agent.name = "NavigationAgent3D"
		_nav_agent.simplify_path = true
		add_child(_nav_agent)

	# ── RayCast3D for line-of-sight checks — same auto-create pattern.
	_vision_ray = get_node_or_null("VisionRay") as RayCast3D
	if _vision_ray == null:
		_vision_ray = RayCast3D.new()
		_vision_ray.name = "VisionRay"
		_vision_ray.enabled = true
		add_child(_vision_ray)

	# ── Connect to player's made_noise signal if the player has one.
	if _player and _player.has_signal("made_noise"):
		if not _player.made_noise.is_connected(hear_sound):
			_player.made_noise.connect(hear_sound)

	# Find or build the AnimationPlayer and load UAL animations.
	_skeleton = _find_skeleton(self)
	_anim = _find_anim_player(self)
	if _skeleton and _anim == null:
		# Bestiary GLBs ship with no AnimationPlayer of their own.
		# Create one as a sibling of the Skeleton3D so bone track paths
		# resolve the same way they do in the UAL source scene.
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		_skeleton.get_parent().add_child(_anim)
	if _anim and _skeleton:
		_merge_ual_animations()
		_set_loop("Idle_Loop")
		_set_loop("Walk_Loop")
		_set_loop("Jog_Fwd_Loop")

	var hurtbox := get_node_or_null("HurtBox") as Area3D
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_apply_visuals()
	_update_label()
	_start_idle()


# ── ANIMATION LOADING ─────────────────────────────────────────────────────────

func _merge_ual_animations() -> void:
	## Pulls every clip from UAL1_Standard.glb into this enemy's AnimationPlayer,
	## rewriting each track's NodePath to point at our skeleton instead of the
	## library scene's skeleton. Same technique as player_3d.gd.
	if not _anim.has_animation_library(""):
		_anim.add_animation_library("", AnimationLibrary.new())
	var dst_lib := _anim.get_animation_library("")

	# root_node defaults to ".." (the AnimationPlayer's parent).
	var anim_root := _anim.get_node(_anim.root_node)
	var skel_rel := anim_root.get_path_to(_skeleton)

	var lib_scene: Node = UAL_SCENE.instantiate()
	var src_player := _find_anim_player(lib_scene)
	if src_player:
		for lib_name in src_player.get_animation_library_list():
			var src_lib := src_player.get_animation_library(lib_name)
			for anim_name in src_lib.get_animation_list():
				if dst_lib.has_animation(anim_name):
					continue
				var anim: Animation = src_lib.get_animation(anim_name).duplicate(true)
				for i in anim.get_track_count():
					var subpath := anim.track_get_path(i).get_concatenated_subnames()
					anim.track_set_path(i, NodePath(str(skel_rel) + ":" + subpath))
				dst_lib.add_animation(anim_name, anim)
	lib_scene.queue_free()


func _set_loop(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var r := _find_anim_player(child)
		if r:
			return r
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var r := _find_skeleton(child)
		if r:
			return r
	return null


# ── PHYSICS ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _dying:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _vision_cooldown > 0.0:
		_vision_cooldown -= delta

	if _player == null:
		move_and_slide()
		return

	var dist := global_position.distance_to(_player.global_position)

	match _state:
		State.IDLE:
			_tick_idle(delta)
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 4 * delta)
			if dist < detection_range and _can_see_player():
				_set_state(State.CHASE)

		State.WANDER:
			_tick_wander(delta, dist)

		State.CHASE:
			_tick_chase(delta, dist)

		State.SEARCH:
			_tick_search(delta)

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 4 * delta)
			_face_player()
			if dist > attack_range * 1.2:
				_set_state(State.CHASE)
			elif _can_attack:
				_do_attack()

	move_and_slide()


# ── STATE HELPERS ─────────────────────────────────────────────────────────────

func _set_state(s: State) -> void:
	_state = s
	match s:
		State.IDLE:
			_start_idle()
		State.WANDER:
			_pick_wander_target()
		State.CHASE:
			_play_anim("run")
		State.SEARCH:
			_play_anim("walk")
		State.ATTACK:
			pass


func _start_idle() -> void:
	_idle_timer = randf_range(idle_time_min, idle_time_max)
	_play_anim("idle")


func _tick_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_set_state(State.WANDER)


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(2.0, wander_radius)
	_wander_target = _spawn_position + Vector3(
		cos(angle) * radius,
		0.0,
		sin(angle) * radius
	)
	_play_anim("walk")


func _tick_wander(delta: float, dist_to_player: float) -> void:
	if dist_to_player < detection_range and _can_see_player():
		_set_state(State.CHASE)
		return

	if _nav_agent:
		# Nav-based wander: drive agent to wander target
		if _nav_agent.is_navigation_finished():
			_pick_wander_target()
			_nav_agent.target_position = _wander_target
		_nav_move(move_speed * 0.6)
	else:
		# Fallback: direct movement
		var to_target := _wander_target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.5:
			_set_state(State.IDLE)
			return
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed * 0.6
		velocity.z = dir.z * move_speed * 0.6
		rotation.y = atan2(-dir.x, -dir.z)


func _tick_chase(delta: float, dist: float) -> void:
	# Lost sight and out of range → search last known position
	if dist > lose_range or not _can_see_player():
		if dist > lose_range:
			_last_known_pos = _player.global_position
			_set_state(State.SEARCH)
			return

	if dist <= attack_range:
		_set_state(State.ATTACK)
		return

	_last_known_pos = _player.global_position

	if _nav_agent:
		_nav_agent.target_position = _player.global_position
		_nav_move(move_speed)
		# Face the player directly while chasing
		var look_dir := _player.global_position - global_position
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.01:
			rotation.y = atan2(-look_dir.x, -look_dir.z)
	else:
		var dir := (_player.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			rotation.y = atan2(-dir.x, -dir.z)


func _tick_search(delta: float) -> void:
	## Move to last-known position. If player is spotted en route, re-enter CHASE.
	var dist := global_position.distance_to(_player.global_position)
	if dist < detection_range and _can_see_player():
		_set_state(State.CHASE)
		return

	if _nav_agent:
		_nav_agent.target_position = _last_known_pos
		if _nav_agent.is_navigation_finished():
			_set_state(State.IDLE)
			return
		_nav_move(move_speed * 0.7)
	else:
		var to_last := _last_known_pos - global_position
		to_last.y = 0.0
		if to_last.length() < 1.0:
			_set_state(State.IDLE)
			return
		var dir := to_last.normalized()
		velocity.x = dir.x * move_speed * 0.7
		velocity.z = dir.z * move_speed * 0.7
		rotation.y = atan2(-dir.x, -dir.z)


## Drive velocity using NavigationAgent3D's next path position.
func _nav_move(spd: float) -> void:
	if not _nav_agent:
		return
	var next := _nav_agent.get_next_path_position()
	var dir := (next - global_position).normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() > 0.01:
		rotation.y = atan2(-flat_dir.x, -flat_dir.z)


## Line-of-sight check — uses RayCast3D; falls back to true if no ray.
func _can_see_player() -> bool:
	if not is_instance_valid(_player):
		return false
	if _vision_ray == null:
		return true  # No ray — assume visible
	if _vision_cooldown > 0.0:
		return _vision_ray.is_colliding() and (
			_vision_ray.get_collider() == _player or
			_vision_ray.get_collider().is_in_group("player")
		)
	_vision_cooldown = _VISION_INTERVAL
	_vision_ray.target_position = _vision_ray.to_local(_player.global_position + Vector3(0, 1.0, 0))
	_vision_ray.force_raycast_update()
	if not _vision_ray.is_colliding():
		return false
	var col := _vision_ray.get_collider()
	return col == _player or col.is_in_group("player")


## Called when the player (or terrain) emits made_noise(origin, volume).
## volume 0.0–1.0; range = hearing_range * volume.
func hear_sound(origin: Vector3, volume: float) -> void:
	if _state == State.CHASE or _state == State.ATTACK:
		return
	if global_position.distance_to(origin) <= hearing_range * volume:
		_last_known_pos = origin
		_set_state(State.SEARCH)


func _face_player() -> void:
	var dir := (_player.global_position - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)


# ── ATTACK ────────────────────────────────────────────────────────────────────

func _do_attack() -> void:
	_can_attack = false
	_play_anim("attack")
	if _player.has_method("take_damage"):
		_player.take_damage(hit_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	if not _dying:
		_can_attack = true
		if _state == State.ATTACK:
			_play_anim("idle")


# ── DAMAGE / DEATH ────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _dying:
		return
	health -= amount
	_update_label()
	_spawn_damage_number(amount)
	_flash()
	if health <= 0:
		_die()


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if area.name == "AttackHitbox":
		take_damage(enemy_level * 5 + 10)


func _die() -> void:
	_dying = true
	set_physics_process(false)
	emit_signal("died", self)
	_play_anim("death")
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
		elif child is Area3D:
			(child as Area3D).monitoring = false
			(child as Area3D).monitorable = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.12)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_delay(0.12)
	await get_tree().create_timer(0.35).timeout
	queue_free()


# ── ANIMATION PLAYBACK ────────────────────────────────────────────────────────

func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	## UAL1 name first, then legacy fallbacks for any non-UAL enemy scenes.
	var candidates: Array[String] = []
	match anim_name:
		"idle":
			candidates = ["Idle_Loop", "Idle", "idle", "IDLE", "Stand", "stand"]
		"walk":
			candidates = ["Walk_Loop", "Walk", "walk", "WALK"]
		"run":
			candidates = ["Jog_Fwd_Loop", "Sprint_Loop", "Run", "run", "RUN", "Walk_Loop", "Walk"]
		"attack":
			candidates = ["Punch_Cross", "Punch_Jab", "Attack", "attack", "Slash", "slash"]
		"death":
			candidates = ["Death01", "Death", "death", "Die", "die"]
	for c in candidates:
		if _anim.has_animation(c):
			if _anim.current_animation != c:
				_anim.play(c)
			return
	# Fallback — keep whatever is currently playing


# ── VISUALS ───────────────────────────────────────────────────────────────────

func _flash() -> void:
	_set_all_albedo(Color.WHITE)
	await get_tree().create_timer(0.08).timeout
	if not _dying:
		_restore_visuals()


func _apply_visuals() -> void:
	await get_tree().process_frame
	_save_materials()
	if not preserve_textures:
		_set_all_albedo(tint_color)


func _save_materials() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var mats: Array = []
		for i: int in mi.mesh.get_surface_count():
			mats.append(mi.get_active_material(i))
		_saved_mats[mi] = mats


func _restore_visuals() -> void:
	if preserve_textures:
		for mi: Object in _saved_mats.keys():
			if not is_instance_valid(mi as Node):
				continue
			var mesh_inst := mi as MeshInstance3D
			var mats: Array = _saved_mats[mi]
			for i: int in mats.size():
				if i < mesh_inst.mesh.get_surface_count():
					mesh_inst.set_surface_override_material(i, null)
	else:
		_set_all_albedo(tint_color)


func _set_all_albedo(color: Color) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, mat)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, out)


func _update_label() -> void:
	var label := get_node_or_null("HealthLabel") as Label3D
	if label:
		label.text = str(max(0, health)) + " / " + str(max_health)


func _spawn_damage_number(amount: int) -> void:
	var num: Node = DamageNumberScene.instantiate()
	get_parent().add_child(num)
	num.global_position = global_position + Vector3(
		randf_range(-0.3, 0.3), 1.8, randf_range(-0.3, 0.3)
	)
	if num.has_method("setup"):
		num.setup(amount)
