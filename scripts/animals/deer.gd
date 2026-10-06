extends CharacterBody3D
## Deer — passive grazing animal.
## - Flees wolves and player (if attacked)
## - Regenerates health slowly when safe
## - Notifies nearby wolves when killed

const GRAVITY:         float = 20.0
const GRAZE_SPEED:     float = 0.8
const WALK_SPEED:      float = 2.0
const FLEE_SPEED:      float = 9.0
const MAX_HEALTH:      int   = 50
const DETECT_WOLF:     float = 14.0   ## Flee radius for wolves
const DETECT_PLAYER:   float = 8.0    ## Flee radius for player (only if attacked)
const SAFE_DIST:       float = 20.0   ## Stop fleeing once this far from threat
const REGEN_RATE:      float = 3.0    ## Seconds between HP ticks
const REGEN_AMOUNT:    int   = 5
const GRAZE_TIME_MIN:  float = 5.0
const GRAZE_TIME_MAX:  float = 12.0

@export var wander_radius: float = 18.0

enum State { GRAZE, WANDER, FLEE, DEAD }

var health:          int   = MAX_HEALTH
var _state:          State = State.GRAZE
var _nav:            NavigationAgent3D = null
var _anim:           AnimationPlayer = null
var _spawn_pos:      Vector3 = Vector3.ZERO
var _wander_target:  Vector3 = Vector3.ZERO
var _graze_timer:    float  = 0.0
var _regen_timer:    float  = 0.0
var _flee_target:    Vector3 = Vector3.ZERO
var _flee_from:      Vector3 = Vector3.ZERO
var _dying:          bool   = false
var _was_attacked:   bool   = false   ## True if player attacked this deer
var _cur_anim:       String = ""

## Animation names resolved at runtime
var _a_idle:   String = ""
var _a_walk:   String = ""
var _a_run:    String = ""
var _a_eat:    String = ""
var _a_death:  String = ""


func _ready() -> void:
	add_to_group("deer")
	add_to_group("animal")
	health = MAX_HEALTH
	_spawn_pos = global_position

	_nav = NavigationAgent3D.new()
	_nav.name = "NavigationAgent3D"
	add_child(_nav)

	var hurtbox := get_node_or_null("HurtBox") as Area3D
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	await get_tree().process_frame
	_anim = _find_anim_player(self)
	if _anim:
		_discover_anims()
	_set_graze()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _state:
		State.GRAZE:  _tick_graze(delta)
		State.WANDER: _tick_wander(delta)
		State.FLEE:   _tick_flee(delta)

	move_and_slide()


# ── State ticks ───────────────────────────────────────────────────────────────

func _tick_graze(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
	_graze_timer -= delta

	_tick_regen(delta)
	_scan_for_threats()

	if _graze_timer <= 0.0:
		if randf() > 0.5:
			_pick_wander_target()
		else:
			_set_graze()


func _tick_wander(delta: float) -> void:
	_tick_regen(delta)
	_scan_for_threats()
	_move_toward(_wander_target, WALK_SPEED)

	var dist := global_position.distance_to(_wander_target)
	if dist < 1.5:
		_set_graze()


func _tick_flee(delta: float) -> void:
	## Run away from threat
	var dir := (global_position - _flee_from)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * FLEE_SPEED
		velocity.z = dir.z * FLEE_SPEED
		rotation.y = atan2(dir.x, dir.z)
	_play_anim(_a_run if _a_run != "" else _a_walk)

	var dist_safe := global_position.distance_to(_flee_from)
	if dist_safe >= SAFE_DIST:
		_set_graze()
	else:
		## Keep scanning to update flee direction if threat moved
		_scan_for_threats()


func _tick_regen(delta: float) -> void:
	if health >= MAX_HEALTH:
		return
	_regen_timer -= delta
	if _regen_timer <= 0.0:
		_regen_timer = REGEN_RATE
		health = clampi(health + REGEN_AMOUNT, 0, MAX_HEALTH)


func _scan_for_threats() -> void:
	## Check for wolves
	var nearest_wolf: Node3D = null
	var nearest_wolf_d: float = DETECT_WOLF
	for w: Node in get_tree().get_nodes_in_group("wolf"):
		if not is_instance_valid(w) or not w is Node3D:
			continue
		var d := global_position.distance_to((w as Node3D).global_position)
		if d < nearest_wolf_d:
			nearest_wolf_d = d
			nearest_wolf = w as Node3D

	if nearest_wolf:
		_flee_from = nearest_wolf.global_position
		_state = State.FLEE
		return

	## If previously attacked by player, also flee from player
	if _was_attacked:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			var dp := global_position.distance_to(player.global_position)
			if dp < DETECT_PLAYER:
				_flee_from = player.global_position
				_state = State.FLEE


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_graze() -> void:
	_state = State.GRAZE
	_graze_timer = randf_range(GRAZE_TIME_MIN, GRAZE_TIME_MAX)
	_play_anim(_a_eat if _a_eat != "" else _a_idle)


func _pick_wander_target() -> void:
	_wander_target = _spawn_pos + Vector3(
		randf_range(-wander_radius, wander_radius), 0.0,
		randf_range(-wander_radius, wander_radius))
	_state = State.WANDER
	_play_anim(_a_walk)


func _move_toward(target: Vector3, speed: float) -> void:
	if _nav:
		_nav.target_position = target
		if not _nav.is_navigation_finished():
			var next := _nav.get_next_path_position()
			target = next
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.04:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 2.0)
		velocity.z = move_toward(velocity.z, 0, speed * 2.0)


# ── Damage / death ─────────────────────────────────────────────────────────

func take_damage(amount: int, attacker: Node = null) -> void:
	if _dying:
		return
	health -= amount
	if attacker and attacker.is_in_group("player"):
		_was_attacked = true
		_flee_from = (attacker as Node3D).global_position
		_state = State.FLEE
	elif attacker and attacker is Node3D:
		_flee_from = (attacker as Node3D).global_position
		_state = State.FLEE
	if health <= 0:
		_die()


func _die() -> void:
	_dying = true
	_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim(_a_death)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true

	## Notify nearby wolves so they can eat
	for w: Node in get_tree().get_nodes_in_group("wolf"):
		if w.has_method("notify_deer_killed"):
			w.notify_deer_killed(self)

	await get_tree().create_timer(5.0).timeout
	queue_free()


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dying:
		return
	if area.is_in_group("attack_hitbox") or area.name == "AttackHitbox":
		var dmg: int = 15
		if area.has_method("get") and area.get("damage") != null:
			dmg = int(area.get("damage"))
		take_damage(dmg, area.get_parent())


# ── Animation ─────────────────────────────────────────────────────────────────

func _discover_anims() -> void:
	if _anim == null:
		return
	var names: PackedStringArray = PackedStringArray()
	for lib: StringName in _anim.get_animation_library_list():
		for a: StringName in _anim.get_animation_library(lib).get_animation_list():
			var full: String = (String(lib) + "/" + String(a)) if lib != &"" else String(a)
			names.append(full)
			print("[Deer] anim: ", full)

	for n: String in names:
		var l := n.to_lower()
		if _a_idle == "" and ("idle" in l or "stand" in l or "rest" in l):
			_a_idle = n
		elif _a_walk == "" and ("walk" in l):
			_a_walk = n
		elif _a_run == "" and ("run" in l or "trot" in l or "gallop" in l or "sprint" in l):
			_a_run = n
		elif _a_eat == "" and ("eat" in l or "graze" in l or "chew" in l or "feed" in l):
			_a_eat = n
		elif _a_death == "" and ("death" in l or "die" in l or "dead" in l or "fall" in l):
			_a_death = n

	if _a_run == "" and _a_walk != "":
		_a_run = _a_walk
	if _a_idle == "" and _a_walk != "":
		_a_idle = _a_walk


func _play_anim(anim: String) -> void:
	if _anim == null or anim == "" or _cur_anim == anim:
		return
	if not _anim.has_animation(anim):
		return
	_cur_anim = anim
	_anim.play(anim)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var r: AnimationPlayer = _find_anim_player(child)
		if r != null:
			return r
	return null
