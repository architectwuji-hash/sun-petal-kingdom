extends CharacterBody3D

const SPEED: float = 4.0
const DAMAGE: int = 10
const HIT_DIST: float = 1.2
const SIGHT: float = 30.0
const GRAVITY: float = 9.8
const HIT_COOLDOWN: float = 1.0

var hp: int = 100
var _player: CharacterBody3D = null
var _hit_cooldown: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	$HurtBox.area_entered.connect(_on_hurtbox_area_entered)
	_tint_character_red()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if area.name == "AttackHitbox":
		take_damage(25)


func _physics_process(delta: float) -> void:
	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	velocity.y -= GRAVITY * delta

	if _player == null:
		move_and_slide()
		return

	var dist: float = global_position.distance_to(_player.global_position)
	if dist < SIGHT:
		var dir: Vector3 = (_player.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			rotation.y = atan2(-dir.x, -dir.z)
		if dist < HIT_DIST and _hit_cooldown <= 0.0:
			if _player.has_method("set_health"):
				_player.set_health(_player.health - DAMAGE)
			_hit_cooldown = HIT_COOLDOWN
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()


func _tint_character_red() -> void:
	var hostile_mat := StandardMaterial3D.new()
	hostile_mat.albedo_color = Color(0.8, 0.1, 0.1)
	_apply_mat_to_meshes($CharacterModel, hostile_mat)


func _apply_mat_to_meshes(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_idx: int in mesh_instance.mesh.get_surface_count():
				mesh_instance.set_surface_override_material(surface_idx, material)
	for child: Node in node.get_children():
		_apply_mat_to_meshes(child, material)
