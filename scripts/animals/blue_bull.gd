extends CharacterBody3D
## BlueBull — passive grazing animal.
## Wanders and grazes. Can be killed — drops BullMeat on death.

const GRAVITY:        float = 20.0
const WANDER_SPEED:   float = 1.4
const GRAZE_TIME_MIN: float = 4.0
const GRAZE_TIME_MAX: float = 9.0
const MAX_HEALTH:     int   = 60

@export var wander_radius: float = 12.0   ## Set smaller to confine to a pen

enum State { GRAZE, WANDER, DEAD }

var health:         int   = MAX_HEALTH
var _state:         State = State.GRAZE
var _nav:           NavigationAgent3D = null
var _anim:          AnimationPlayer = null
var _spawn_pos:     Vector3 = Vector3.ZERO
var _graze_timer:   float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _dying:         bool  = false
var _cur_anim:      String = ""

## Cow animation names (AnimalArmature|Name from Cow.fbx)
const ANIM_IDLE   := "AnimalArmature|Idle_Headlow"
const ANIM_EAT    := "AnimalArmature|Eating"
const ANIM_WALK   := "AnimalArmature|Walk"
const ANIM_DEATH  := "AnimalArmature|Death"


func _ready() -> void:
	add_to_group("animal")
	_spawn_pos = global_position

	_nav = NavigationAgent3D.new()
	_nav.name = "NavigationAgent3D"
	add_child(_nav)

	var hurtbox := get_node_or_null("HurtBox") as Area3D
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	await get_tree().process_frame
	_anim = _find_anim_player(self)
	_set_graze()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _state:
		State.GRAZE:  _tick_graze(delta)
		State.WANDER: _tick_wander(delta)

	move_and_slide()


func _tick_graze(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0)
	velocity.z = move_toward(velocity.z, 0.0, 10.0)
	_graze_timer -= delta
	if _graze_timer <= 0.0:
		_pick_wander_target()
		_state = State.WANDER


func _tick_wander(_delta: float) -> void:
	if global_position.distance_to(_wander_target) < 1.0:
		_set_graze()
		return
	var next: Vector3
	if _nav != null and _nav.is_navigation_finished() == false:
		_nav.target_position = _wander_target
		var candidate: Vector3 = _nav.get_next_path_position()
		var candidate_dir: Vector3 = candidate - global_position
		candidate_dir.y = 0.0
		if candidate_dir.length_squared() > 0.04:
			next = candidate
		else:
			next = _wander_target
	else:
		next = _wander_target
	var dir: Vector3 = (next - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * WANDER_SPEED
		velocity.z = dir.z * WANDER_SPEED
		rotation.y = atan2(dir.x, dir.z)


func take_damage(amount: int, _attacker: Node = null) -> void:
	if _dying:
		return
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	_dying = true
	_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim(ANIM_DEATH)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	_drop_meat()


func _drop_meat() -> void:
	var meat_scene := load("res://scenes/items/BullMeat.tscn") as PackedScene
	if meat_scene == null:
		queue_free()
		return

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.1)
	glow.light_energy = 0.0
	glow.omni_range = 3.0
	add_child(glow)

	var t1 := create_tween()
	t1.tween_property(glow, "light_energy", 3.0, 0.3)
	t1.tween_property(glow, "light_energy", 1.0, 0.3)
	await t1.finished

	var meat := meat_scene.instantiate() as Node3D
	get_parent().add_child(meat)
	meat.global_position = global_position + Vector3(0, 0.5, 0)

	queue_free()


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dying:
		return
	if area.is_in_group("attack_hitbox") or area.name == "AttackHitbox":
		var dmg: int = 15
		if area.has_method("get") and area.get("damage") != null:
			dmg = int(area.get("damage"))
		take_damage(dmg)


func _set_graze() -> void:
	_state = State.GRAZE
	_graze_timer = randf_range(GRAZE_TIME_MIN, GRAZE_TIME_MAX)
	_play_anim(ANIM_IDLE if randf() > 0.4 else ANIM_EAT)


func _pick_wander_target() -> void:
	_wander_target = _spawn_pos + Vector3(
		randf_range(-wander_radius, wander_radius), 0.0,
		randf_range(-wander_radius, wander_radius))
	_play_anim(ANIM_WALK)


func _play_anim(anim: String) -> void:
	if _anim == null or _cur_anim == anim:
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
