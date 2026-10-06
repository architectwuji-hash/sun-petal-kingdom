extends CharacterBody3D
## Wolf — hunts the player and deer.
## - Attacks player and deer within detection range
## - Retreats when HP drops below 25%
## - Finds downed deer to eat and restore HP

const GRAVITY:            float = 20.0
const WALK_SPEED:         float = 3.0
const CHASE_SPEED:        float = 8.0
const RETREAT_SPEED:      float = 7.0
const MAX_HEALTH:         int   = 80
const RETREAT_HP_PCT:     float = 0.25
const HEAL_FROM_DEER:     int   = 35
const EAT_DURATION:       float = 4.5
const ATTACK_DAMAGE:      int   = 18
const ATTACK_COOLDOWN:    float = 1.8
const DETECTION_RANGE:    float = 20.0
const DEER_DETECT_RANGE:  float = 25.0
const ATTACK_RANGE:       float = 2.2
const LOSE_RANGE:         float = 32.0
const RETREAT_DIST:       float = 28.0

@export var wander_radius: float = 22.0

enum State { WANDER, CHASE_PLAYER, CHASE_DEER, RETREAT, EAT, DEAD }

var health:          int   = MAX_HEALTH
var _state:          State = State.WANDER
var _nav:            NavigationAgent3D = null
var _anim:           AnimationPlayer = null
var _spawn_pos:      Vector3 = Vector3.ZERO
var _wander_target:  Vector3 = Vector3.ZERO
var _wander_timer:   float  = 0.0
var _atk_cooldown:   float  = 0.0
var _player:         Node3D = null
var _target_deer:    Node3D = null
var _eat_timer:      float  = 0.0
var _retreat_from:   Vector3 = Vector3.ZERO
var _dying:          bool   = false
var _cur_anim:       String = ""

var _a_idle:   String = ""
var _a_walk:   String = ""
var _a_run:    String = ""
var _a_attack: String = ""
var _a_death:  String = ""
var _a_eat:    String = ""


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("wolf")
	health = MAX_HEALTH
	_spawn_pos = global_position
	_player = get_tree().get_first_node_in_group("player") as Node3D

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
	_set_wander()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_atk_cooldown = max(_atk_cooldown - delta, 0.0)

	match _state:
		State.WANDER:       _tick_wander(delta)
		State.CHASE_PLAYER: _tick_chase_player(delta)
		State.CHASE_DEER:   _tick_chase_deer(delta)
		State.RETREAT:      _tick_retreat(delta)
		State.EAT:          _tick_eat(delta)

	move_and_slide()


func _tick_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_target()

	_move_toward(_wander_target, WALK_SPEED)

	if _player and is_instance_valid(_player):
		var d := global_position.distance_to(_player.global_position)
		if d < DETECTION_RANGE:
			_state = State.CHASE_PLAYER
			return

	var deer := _find_nearest_deer()
	if deer and global_position.distance_to(deer.global_position) < DEER_DETECT_RANGE:
		_target_deer = deer
		_state = State.CHASE_DEER


func _tick_chase_player(delta: float) -> void:
	if _is_low_health():
		_begin_retreat(_player.global_position if _player else global_position)
		return

	if not _player or not is_instance_valid(_player):
		_set_wander()
		return

	var d := global_position.distance_to(_player.global_position)
	if d > LOSE_RANGE:
		_set_wander()
		return

	if d <= ATTACK_RANGE and _atk_cooldown <= 0.0:
		_do_attack_player()
	else:
		_move_toward(_player.global_position, CHASE_SPEED)
		_play_anim(_a_run if _a_run != "" else _a_walk)


func _tick_chase_deer(delta: float) -> void:
	if _is_low_health():
		_begin_retreat(global_position)
		return

	if _player and is_instance_valid(_player):
		var dp := global_position.distance_to(_player.global_position)
		if dp < DETECTION_RANGE:
			_state = State.CHASE_PLAYER
			return

	if not is_instance_valid(_target_deer):
		_target_deer = _find_nearest_deer()
		if _target_deer == null:
			_set_wander()
			return

	var d := global_position.distance_to(_target_deer.global_position)
	if d > LOSE_RANGE:
		_set_wander()
		return

	if d <= ATTACK_RANGE and _atk_cooldown <= 0.0:
		_do_attack_deer()
	else:
		_move_toward(_target_deer.global_position, CHASE_SPEED)
		_play_anim(_a_run if _a_run != "" else _a_walk)


func _tick_retreat(delta: float) -> void:
	var dir := (global_position - _retreat_from)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * RETREAT_SPEED
		velocity.z = dir.z * RETREAT_SPEED
		rotation.y = atan2(dir.x, dir.z)
	_play_anim(_a_run if _a_run != "" else _a_walk)

	var dist := global_position.distance_to(_retreat_from)
	if dist >= RETREAT_DIST:
		var prey := _find_nearest_deer()
		if prey and global_position.distance_to(prey.global_position) < DEER_DETECT_RANGE:
			_target_deer = prey
			_state = State.CHASE_DEER
		else:
			_set_wander()


func _tick_eat(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 60.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 60.0 * delta)
	_play_anim(_a_eat if _a_eat != "" else _a_idle)
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		health = clampi(health + HEAL_FROM_DEER, 0, MAX_HEALTH)
		_target_deer = null
		_set_wander()


func _do_attack_player() -> void:
	_atk_cooldown = ATTACK_COOLDOWN
	_play_anim(_a_attack)
	if _player and is_instance_valid(_player) and _player.has_method("take_damage"):
		_player.take_damage(ATTACK_DAMAGE)


func _do_attack_deer() -> void:
	if not is_instance_valid(_target_deer):
		return
	_atk_cooldown = ATTACK_COOLDOWN
	_play_anim(_a_attack)
	if _target_deer.has_method("take_damage"):
		_target_deer.take_damage(ATTACK_DAMAGE, self)


func _begin_retreat(from_pos: Vector3) -> void:
	_retreat_from = from_pos
	_state = State.RETREAT


func _set_wander() -> void:
	_state = State.WANDER
	_pick_wander_target()


func _pick_wander_target() -> void:
	_wander_target = _spawn_pos + Vector3(
		randf_range(-wander_radius, wander_radius), 0.0,
		randf_range(-wander_radius, wander_radius))
	_wander_timer = randf_range(4.0, 9.0)
	_play_anim(_a_walk)


func _move_toward(target: Vector3, speed: float) -> void:
	var dest: Vector3 = target
	if _nav:
		_nav.target_position = target
		if not _nav.is_navigation_finished():
			dest = _nav.get_next_path_position()
	var dir: Vector3 = dest - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.04:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 2.0)
		velocity.z = move_toward(velocity.z, 0, speed * 2.0)


func _find_nearest_deer() -> Node3D:
	var best: Node3D = null
	var best_d := DEER_DETECT_RANGE
	for d: Node in get_tree().get_nodes_in_group("deer"):
		if not is_instance_valid(d) or not d is Node3D:
			continue
		var dist := global_position.distance_to((d as Node3D).global_position)
		if dist < best_d:
			best_d = dist
			best = d as Node3D
	return best


func _is_low_health() -> bool:
	return float(health) / float(MAX_HEALTH) < RETREAT_HP_PCT


func take_damage(amount: int, _attacker: Node = null) -> void:
	if _dying:
		return
	health -= amount
	if health <= 0:
		_die()
		return
	if _attacker and _attacker.is_in_group("player"):
		if _is_low_health():
			_begin_retreat((_attacker as Node3D).global_position)
		else:
			_state = State.CHASE_PLAYER
	elif _is_low_health() and _state != State.RETREAT:
		var from_pos := global_position
		if _attacker and _attacker is Node3D:
			from_pos = (_attacker as Node3D).global_position
		_begin_retreat(from_pos)


func _die() -> void:
	_dying = true
	_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim(_a_death)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	await get_tree().create_timer(4.0).timeout
	queue_free()


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dying:
		return
	if area.is_in_group("attack_hitbox") or area.name == "AttackHitbox":
		var dmg: int = 20
		if area.has_method("get") and area.get("damage") != null:
			dmg = int(area.get("damage"))
		take_damage(dmg, area.get_parent())


func notify_deer_killed(deer_node: Node3D) -> void:
	if _dying or _state == State.DEAD:
		return
	if global_position.distance_to(deer_node.global_position) < DEER_DETECT_RANGE:
		_eat_timer = EAT_DURATION
		_target_deer = deer_node
		_state = State.EAT


func _discover_anims() -> void:
	if _anim == null:
		return
	var names: PackedStringArray = PackedStringArray()
	for lib: StringName in _anim.get_animation_library_list():
		for a: StringName in _anim.get_animation_library(lib).get_animation_list():
			var full: String = (String(lib) + "/" + String(a)) if lib != &"" else String(a)
			names.append(full)
			print("[Wolf] anim: ", full)

	for n: String in names:
		var l := n.to_lower()
		if _a_idle == "" and ("idle" in l or "stand" in l):
			_a_idle = n
		elif _a_walk == "" and ("walk" in l):
			_a_walk = n
		elif _a_run == "" and ("run" in l or "trot" in l or "gallop" in l):
			_a_run = n
		elif _a_attack == "" and ("attack" in l or "bite" in l or "snap" in l):
			_a_attack = n
		elif _a_death == "" and ("death" in l or "die" in l or "dead" in l or "fall" in l):
			_a_death = n
		elif _a_eat == "" and ("eat" in l or "chew" in l or "gnaw" in l or "feed" in l):
			_a_eat = n

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
