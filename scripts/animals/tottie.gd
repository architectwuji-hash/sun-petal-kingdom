extends CharacterBody3D
## Tottie — Chicken nugget humanoid. Food creature.
## Roams in groups of 3. Eats trees (chips away health). Flees the player.
## On death: stays on the floor as a corpse until picked up (press E) → inventory.

# ── ANIMATION FBX SCENES ─────────────────────────────────────────────────────
# Each Mixamo FBX contains the full Tottie mesh + skeleton + one animation.
# We swap which one is visible based on state — no retargeting needed.
const ANIM_WALK_SCENE:   PackedScene = preload("res://assets/animations/tottie/Dwarf Walk.fbx")
const ANIM_SPRINT_SCENE: PackedScene = preload("res://assets/animations/tottie/Sprint.fbx")
const ANIM_DIE_SCENE:    PackedScene = preload("res://assets/animations/tottie/Dying Backwards.fbx")
const ANIM_DANCE_SCENE:  PackedScene = preload("res://assets/animations/tottie/Dancing.fbx")

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
const GRAVITY:            float = 20.0
const ROAM_SPEED:         float = 1.6
const FLEE_SPEED:         float = 3.8
const FLEE_RADIUS:        float = 8.0
const ROAM_RADIUS:        float = 14.0
const ROAM_CHANGE_TIME:   float = 6.0
const EAT_RANGE:          float = 2.5
const EAT_DAMAGE_RATE:    float = 0.35
const EAT_TICK_TIME:      float = 6.0
const PICKUP_RANGE:       float = 2.0
const MAX_HEALTH:         int   = 20
const MODEL_SCALE:        float = 1.5

# ── STATE ENUM ────────────────────────────────────────────────────────────────
enum State { ROAM, FLEE, EAT_TREE, DEAD }

# ── RUNTIME ───────────────────────────────────────────────────────────────────
var health:            int    = MAX_HEALTH
var _state:            State  = State.ROAM
var _spawn_pos:        Vector3 = Vector3.ZERO
var _roam_target:      Vector3 = Vector3.ZERO
var _roam_timer:       float  = 0.0
var _eat_timer:        float  = 0.0
var _target_tree:      Node3D = null   # damageable_tree node (when available)
var _eat_pos:          Vector3 = Vector3(INF, INF, INF)  # world position of tree to walk to
var _terrain:          Node3D = null   # forest_terrain node for chop_at()
var _nav:              NavigationAgent3D = null
var _dead:             bool   = false
var _pickup_label:     Label  = null
var _pickup_layer:     CanvasLayer = null
var _player_nearby:    bool   = false
var _pickup_cooldown:  float  = 0.0

# Visual nodes — one per animation state
var _vis_walk:   Node3D = null
var _vis_sprint: Node3D = null
var _vis_die:    Node3D = null
var _vis_dance:  Node3D = null
var _ap_walk:    AnimationPlayer = null
var _ap_sprint:  AnimationPlayer = null
var _ap_die:     AnimationPlayer = null
var _ap_dance:   AnimationPlayer = null
var _current_visual: String = ""

# Health bar nodes
var _hbar_root:  Node3D = null
var _hbar_bg:    MeshInstance3D = null
var _hbar_fill:  MeshInstance3D = null

# ── SIGNALS ───────────────────────────────────────────────────────────────────
signal tottie_harvested(tottie: Node3D)


func _ready() -> void:
	add_to_group("tottie")
	add_to_group("animal")
	_spawn_pos = global_position

	_nav = NavigationAgent3D.new()
	_nav.name = "NavigationAgent3D"
	add_child(_nav)

	# ── Load one visual mesh per animation ────────────────────────────────
	var rw := _load_visual(ANIM_WALK_SCENE)
	_vis_walk  = rw[0]; _ap_walk  = rw[1]

	var rs := _load_visual(ANIM_SPRINT_SCENE)
	_vis_sprint = rs[0]; _ap_sprint = rs[1]

	var rd := _load_visual(ANIM_DIE_SCENE)
	_vis_die = rd[0]; _ap_die = rd[1]

	var rda := _load_visual(ANIM_DANCE_SCENE)
	_vis_dance = rda[0]; _ap_dance = rda[1]

	# Start walking
	_switch_visual("walk")

	# ── 3D Health bar ─────────────────────────────────────────────────────
	_create_health_bar()

	# ── Find forest terrain for multi-mesh tree chopping ──────────────────
	var terrain_nodes := get_tree().get_nodes_in_group("harvestable_trees")
	if terrain_nodes.size() > 0:
		_terrain = terrain_nodes[0] as Node3D

	# Hurtbox signal
	var hurtbox := get_node_or_null("HurtBox") as Area3D
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Detection area for player proximity
	var detection := Area3D.new()
	detection.name = "DetectionArea"
	var det_shape := SphereShape3D.new()
	det_shape.radius = FLEE_RADIUS
	var col := CollisionShape3D.new()
	col.shape = det_shape
	detection.add_child(col)
	detection.body_entered.connect(_on_detection_body_entered)
	detection.body_exited.connect(_on_detection_body_exited)
	detection.collision_layer = 0
	detection.collision_mask = 2
	add_child(detection)

	# Pickup prompt label
	_pickup_layer = CanvasLayer.new()
	_pickup_layer.layer = 4
	add_child(_pickup_layer)
	_pickup_label = Label.new()
	_pickup_label.text = "[ E ] Pick up Tottie"
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.add_theme_font_size_override("font_size", 14)
	_pickup_label.visible = false
	_pickup_layer.add_child(_pickup_label)

	_pick_roam_target()


# ── HEALTH BAR ────────────────────────────────────────────────────────────────

func _create_health_bar() -> void:
	_hbar_root = Node3D.new()
	_hbar_root.position = Vector3(0.0, 2.2, 0.0)
	add_child(_hbar_root)

	# Background bar (dark red)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.7, 0.09)
	_hbar_bg = MeshInstance3D.new()
	_hbar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.35, 0.0, 0.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hbar_bg.set_surface_override_material(0, bg_mat)
	_hbar_root.add_child(_hbar_bg)

	# Fill bar (green, slightly in front)
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.7, 0.09)
	_hbar_fill = MeshInstance3D.new()
	_hbar_fill.mesh = fill_mesh
	_hbar_fill.position.z = 0.005
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.05, 0.85, 0.1)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hbar_fill.set_surface_override_material(0, fill_mat)
	_hbar_root.add_child(_hbar_fill)


func _update_health_bar() -> void:
	if _hbar_fill == null:
		return
	var ratio: float = clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	var full_w: float = 0.7
	var fill_w: float = full_w * ratio
	# Resize fill mesh
	var fill_mesh := _hbar_fill.mesh as QuadMesh
	fill_mesh.size = Vector2(fill_w, 0.09)
	# Left-align: shift fill left as it shrinks
	_hbar_fill.position.x = (fill_w - full_w) * 0.5
	# Color: green → red as health drops
	var fill_mat := _hbar_fill.get_surface_override_material(0) as StandardMaterial3D
	if fill_mat:
		fill_mat.albedo_color = Color(1.0 - ratio, ratio * 0.85, 0.05)


func _process(_delta: float) -> void:
	# Rotate health bar root to always face the active camera
	if _hbar_root == null or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var target := cam.global_position
	target.y = _hbar_root.global_position.y
	if _hbar_root.global_position.distance_squared_to(target) > 0.01:
		_hbar_root.look_at(target, Vector3.UP)
		_hbar_root.rotate_y(PI)  # look_at aims -Z; flip so +Z (quad face) faces cam


# ── ANIMATION HELPERS ─────────────────────────────────────────────────────────

# Load an animation FBX scene as a hidden child; return [Node3D, AnimationPlayer]
func _load_visual(scene: PackedScene) -> Array:
	var inst: Node3D = scene.instantiate() as Node3D
	inst.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
	inst.visible = false
	add_child(inst)
	var ap: AnimationPlayer = _find_anim_player(inst)
	if ap:
		# Loop all animations by default
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				lib.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return [inst, ap]


# Play the first animation found in an AnimationPlayer
func _autoplay(ap: AnimationPlayer) -> void:
	if ap == null:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var full_name: String = (lib_name + "/" + anim_name) if lib_name != "" else str(anim_name)
			if ap.current_animation != full_name:
				ap.play(full_name)
			return


# Show one visual, hide the others, start its animation
func _switch_visual(key: String) -> void:
	if _current_visual == key:
		return
	_current_visual = key
	var pairs: Dictionary = {
		"walk":   [_vis_walk,   _ap_walk],
		"sprint": [_vis_sprint, _ap_sprint],
		"die":    [_vis_die,    _ap_die],
		"dance":  [_vis_dance,  _ap_dance],
	}
	for k in pairs:
		var pair: Array = pairs[k]
		var node: Node3D = pair[0]
		var ap: AnimationPlayer = pair[1]
		if node:
			node.visible = (k == key)
		if k == key and ap:
			# Death plays once only
			if k == "die":
				for lib_name in ap.get_animation_library_list():
					var lib := ap.get_animation_library(lib_name)
					for anim_name in lib.get_animation_list():
						lib.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
			_autoplay(ap)


# ── PHYSICS ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _dead:
		_tick_dead(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _pickup_cooldown > 0.0:
		_pickup_cooldown -= delta
	match _state:
		State.ROAM:     _tick_roam(delta)
		State.FLEE:     _tick_flee(delta)
		State.EAT_TREE: _tick_eat_tree(delta)
	move_and_slide()


# ── STATE TICKS ───────────────────────────────────────────────────────────────

func _tick_roam(delta: float) -> void:
	_switch_visual("walk")
	if _player_nearby:
		_state = State.FLEE
		return
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		_eat_timer = EAT_TICK_TIME
		if _pick_eat_target():
			_state = State.EAT_TREE
			return
	_roam_timer -= delta
	if _roam_timer <= 0.0 or global_position.distance_to(_roam_target) < 1.2:
		_pick_roam_target()
	_move_toward(_roam_target, ROAM_SPEED, delta)


func _tick_flee(delta: float) -> void:
	_switch_visual("sprint")
	if not _player_nearby:
		_state = State.ROAM
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_state = State.ROAM
		return
	var away: Vector3 = (global_position - player.global_position)
	away.y = 0.0
	if away.length_squared() > 0.01:
		away = away.normalized()
		_move_toward(global_position + away * 6.0, FLEE_SPEED, delta)


func _tick_eat_tree(delta: float) -> void:
	if _player_nearby:
		_target_tree = null
		_eat_pos = Vector3(INF, INF, INF)
		_state = State.FLEE
		return
	# Check damageable_tree node still valid
	if _target_tree != null and not is_instance_valid(_target_tree):
		_target_tree = null
		_eat_pos = Vector3(INF, INF, INF)
		_state = State.ROAM
		return
	# No target at all
	if _eat_pos.x == INF:
		_state = State.ROAM
		return

	var dist: float = global_position.distance_to(_eat_pos)
	if dist > EAT_RANGE:
		# Walk toward tree
		_switch_visual("walk")
		_move_toward(_eat_pos, ROAM_SPEED, delta)
	else:
		# At the tree — dance/munch animation and deal damage on tick
		_switch_visual("dance")
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_eat_timer -= delta
		if _eat_timer <= 0.0:
			_eat_timer = EAT_TICK_TIME
			_do_tree_bite()


func _do_tree_bite() -> void:
	# Option 1: damageable_tree node with take_damage()
	if _target_tree != null and is_instance_valid(_target_tree):
		if _target_tree.has_method("take_damage"):
			_target_tree.take_damage(int(EAT_DAMAGE_RATE * EAT_TICK_TIME))
			return
	# Option 2: forest_terrain chop_at() for multi-mesh trees
	if _terrain != null and _terrain.has_method("chop_at"):
		var hit: bool = _terrain.call("chop_at", global_position, EAT_RANGE, self)
		if not hit:
			# Tree gone or moved — clear target and roam
			_eat_pos = Vector3(INF, INF, INF)
			_target_tree = null
			_state = State.ROAM
		return
	# No valid source — give up
	_eat_pos = Vector3(INF, INF, INF)
	_target_tree = null
	_state = State.ROAM


func _tick_dead(_delta: float) -> void:
	if _pickup_label != null:
		_pickup_label.visible = _player_nearby
	if _player_nearby and _pickup_cooldown <= 0.0 and Input.is_key_pressed(KEY_E):
		_pickup_cooldown = 0.5
		_pickup_by_player()


# ── MOVEMENT HELPER ───────────────────────────────────────────────────────────

func _move_toward(target: Vector3, speed: float, _delta: float) -> void:
	var move_pos: Vector3 = target
	if _nav != null:
		_nav.target_position = target
		var candidate: Vector3 = _nav.get_next_path_position()
		var to_nav: Vector3 = candidate - global_position
		to_nav.y = 0.0
		var to_dest: Vector3 = target - global_position
		to_dest.y = 0.0
		if to_nav.length_squared() > 0.04 and to_nav.dot(to_dest) > 0.0:
			move_pos = candidate
	var dir: Vector3 = move_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0)
		velocity.z = move_toward(velocity.z, 0.0, 10.0)


# ── DAMAGE / DEATH ────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	health = max(health, 0)
	_update_health_bar()
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	_state = State.DEAD
	velocity = Vector3.ZERO
	# Hide health bar on death
	if _hbar_root:
		_hbar_root.visible = false
	# Disable physics collision so player can walk through corpse
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	_switch_visual("die")
	add_to_group("interactable")  # player E key can now pick up
	print("[Tottie] Tottie dropped! Press E to pick up.")


# ── KIPATAH HARVEST ───────────────────────────────────────────────────────────

func harvest_by_kipatah() -> void:
	if _dead:
		emit_signal("tottie_harvested", self)
		queue_free()
		return
	_die()
	await get_tree().create_timer(0.8).timeout
	emit_signal("tottie_harvested", self)
	queue_free()


# ── PLAYER PICKUP ─────────────────────────────────────────────────────────────

func _pickup_by_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if player.has_method("add_item"):
		player.add_item("tottie")
	print("[Tottie] Picked up! Added to player inventory.")
	queue_free()


# ── INTERACT (E key via player _try_interact) ────────────────────────────────

## Called by the player's _try_interact() when this Tottie is in the
## "interactable" group (i.e. dead). Mirrors _pickup_by_player().
func interact(player: Node3D) -> void:
	if not _dead:
		return
	if player.has_method("add_item"):
		player.add_item("tottie")
	print("[Tottie] Picked up via E! Added to player inventory.")
	queue_free()


# ── TREE FINDING ──────────────────────────────────────────────────────────────

## Find and set the nearest tree target. Returns true if a target was found.
func _pick_eat_target() -> bool:
	# 1. Prefer damageable_tree nodes (in "tree" group with take_damage())
	var best_node: Node3D = null
	var best_d: float = ROAM_RADIUS * 1.5
	for t in get_tree().get_nodes_in_group("tree"):
		if not is_instance_valid(t):
			continue
		var d: float = global_position.distance_to((t as Node3D).global_position)
		if d < best_d:
			best_d = d
			best_node = t as Node3D
	if best_node != null:
		_target_tree = best_node
		_eat_pos = best_node.global_position
		return true

	# 2. Fallback: ask forest_terrain for nearest multi-mesh tree position
	if _terrain != null and _terrain.has_method("get_nearest_tree_pos"):
		var pos: Vector3 = _terrain.call("get_nearest_tree_pos", global_position, ROAM_RADIUS * 1.5)
		if pos.x != INF:
			_target_tree = null
			_eat_pos = pos
			return true

	return false


# ── ROAM ──────────────────────────────────────────────────────────────────────

func _pick_roam_target() -> void:
	_roam_target = _spawn_pos + Vector3(
		randf_range(-ROAM_RADIUS, ROAM_RADIUS), 0.0,
		randf_range(-ROAM_RADIUS, ROAM_RADIUS))
	_roam_timer = randf_range(4.0, ROAM_CHANGE_TIME)


# ── PROXIMITY CALLBACKS ───────────────────────────────────────────────────────

func _on_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player3D":
		_player_nearby = true


func _on_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player3D":
		_player_nearby = false


# ── HURTBOX ───────────────────────────────────────────────────────────────────

func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dead:
		return
	if area.is_in_group("attack_hitbox") or area.name == "AttackHitbox":
		var dmg: int = 10
		if area.has_method("get") and area.get("damage") != null:
			dmg = int(area.get("damage"))
		take_damage(dmg)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var r: AnimationPlayer = _find_anim_player(child)
		if r != null:
			return r
	return null
