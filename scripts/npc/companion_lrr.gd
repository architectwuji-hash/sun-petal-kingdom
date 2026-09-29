## companion_lrr.gd — Little Red Riding Hood companion
## Follows the player, auto-aims and fires at the nearest enemy.
## Attach to a CharacterBody3D node named "LittleRedRidingHood".
extends CharacterBody3D
class_name CompanionLRR

@export var follow_distance : float = 2.8
@export var follow_speed    : float = 5.0
@export var detection_range : float = 18.0
@export var fire_rate       : float = 1.2
@export var shot_damage     : int   = 15
@export var shot_speed      : float = 20.0
@export var max_health      : int   = 120
@export var tint_color      : Color = Color(0.9, 0.15, 0.15)

var health : int = max_health
var _player  : Node3D = null
var _anim    : AnimationPlayer = null
var _fire_cd : float = 0.0
var _target  : Node3D = null

const GRAVITY := 20.0
const FOLLOW_OFFSET := Vector3(1.5, 0.0, 0.0)


func _ready() -> void:
	add_to_group("companion")
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_anim   = _find_anim(self)
	_apply_tint()
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_scan_for_target)
	add_child(timer)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _player == null:
		move_and_slide()
		return

	var desired_pos := _player.global_position \
		- _player.global_transform.basis.z.normalized() * follow_distance \
		+ FOLLOW_OFFSET
	var to_dest := desired_pos - global_position
	to_dest.y = 0.0
	var dist := to_dest.length()

	if dist > 0.5:
		var dir := to_dest.normalized()
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed
		rotation.y = atan2(-dir.x, -dir.z)
		_play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, follow_speed * 4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, follow_speed * 4 * delta)
		_play("idle")

	move_and_slide()

	_fire_cd -= delta
	if _target != null and is_instance_valid(_target) and _fire_cd <= 0.0:
		var to_enemy := _target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() <= detection_range:
			rotation.y = atan2(-to_enemy.x, -to_enemy.z)
			_shoot(_target)
			_fire_cd = 1.0 / fire_rate
		else:
			_target = null


func _scan_for_target() -> void:
	var best_dist := detection_range
	var best : Node3D = null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	_target = best


func _shoot(target: Node3D) -> void:
	_play("attack")
	var proj := _make_projectile()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 1.0, 0)
	var dir := (target.global_position + Vector3(0, 0.8, 0) \
		- proj.global_position).normalized()
	proj.set_meta("direction", dir)
	proj.set_meta("damage", shot_damage)
	proj.set_meta("speed", shot_speed)


func _make_projectile() -> Node3D:
	var body := RigidBody3D.new()
	body.gravity_scale = 0.0
	body.collision_layer = 4
	body.collision_mask  = 2
	var mi := MeshInstance3D.new()
	var s   := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	mi.mesh  = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color      = Color(1.0, 0.3, 0.3)
	mat.emission_enabled  = true
	mat.emission          = Color(1.0, 0.1, 0.1)
	mat.emission_energy_multiplier = 3.0
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	(cs.shape as SphereShape3D).radius = 0.12
	body.add_child(cs)
	var life := Timer.new()
	life.wait_time = 2.5
	life.one_shot  = true
	life.autostart = true
	life.timeout.connect(body.queue_free)
	body.add_child(life)
	body.set_script(_make_proj_script())
	return body


func _make_proj_script() -> GDScript:
	var code := """
extends RigidBody3D
func _physics_process(delta):
	var dir = get_meta("direction", Vector3.ZERO)
	var spd = get_meta("speed", 20.0)
	var dmg = get_meta("damage", 15)
	global_position += dir * spd * delta
	for body in get_colliding_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(dmg)
			queue_free()
			return
"""
	var s := GDScript.new()
	s.source_code = code
	return s


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3)
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _play(anim_name: String) -> void:
	if _anim == null:
		return
	var candidates : Array[String] = []
	match anim_name:
		"idle":   candidates = ["Idle_Loop","Idle","idle"]
		"walk":   candidates = ["Walk_Loop","Walk","walk","Jog_Fwd_Loop"]
		"attack": candidates = ["Punch_Cross","Attack","attack","Shoot"]
	for c in candidates:
		if _anim.has_animation(c) and _anim.current_animation != c:
			_anim.play(c)
			return


func _apply_tint() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint_color
	_set_all_albedo(self, mat)


func _set_all_albedo(node: Node, mat: Material) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		for i in (node as MeshInstance3D).mesh.get_surface_count():
			(node as MeshInstance3D).set_surface_override_material(i, mat)
	for child in node.get_children():
		_set_all_albedo(child, mat)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r: return r
	return null
