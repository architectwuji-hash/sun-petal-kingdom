extends Node3D

const BasicEnemyScene := preload("res://scenes/enemies/BasicEnemy.tscn")
const SunflowerPickupScene := preload("res://scenes/world/SunflowerPickup.tscn")
const TREE_SCENES: Array = [
	preload("res://assets/models/nature/MapleTree_1.gltf"),
	preload("res://assets/models/nature/MapleTree_2.gltf"),
	preload("res://assets/models/nature/MapleTree_3.gltf"),
	preload("res://assets/models/nature/MapleTree_4.gltf"),
	preload("res://assets/models/nature/MapleTree_5.gltf"),
	preload("res://assets/models/nature/BirchTree_1.gltf"),
	preload("res://assets/models/nature/BirchTree_2.gltf"),
	preload("res://assets/models/nature/BirchTree_3.gltf"),
	preload("res://assets/models/nature/BirchTree_4.gltf"),
	preload("res://assets/models/nature/BirchTree_5.gltf"),
]
const BUSH_SCENES: Array = [
	preload("res://assets/models/nature/Bush.gltf"),
	preload("res://assets/models/nature/Bush_Flowers.gltf"),
	preload("res://assets/models/nature/Bush_Small.gltf"),
	preload("res://assets/models/nature/Bush_Small_Flowers.gltf"),
]

const ENEMY_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(-22, 0, -18),
	Vector3(18, 0, -25),
	Vector3(-30, 0, 5),
	Vector3(25, 0, 12),
	Vector3(-15, 0, 28),
]

const RESPAWN_DELAY: float = 5.0
const TREE_COUNT: int = 60
const TREE_MIN_DIST: float = 14.0
const TREE_MAX_DIST: float = 90.0
const TREE_SEED: int = 42317

@onready var player: Player = $PlayerSpawn/Player
@onready var hud: HUD = $HUD


func _ready() -> void:
	hud.connect_to_player(player)
	_spawn_trees()
	_spawn_bushes()
	_spawn_initial_enemies()
	_spawn_sunflowers()
	_build_dock()
	_setup_south_cove_trigger()
	_build_campfire_fx()
	_apply_ground_shader()


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var tree_scenes: Array = TREE_SCENES
	for _attempt in range(TREE_COUNT):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(TREE_MIN_DIST, TREE_MAX_DIST)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if abs(pos.x) > 94.0 or abs(pos.z) > 94.0:
			continue
		var tree_scene: PackedScene = tree_scenes[rng.randi_range(0, tree_scenes.size() - 1)]
		var tree: Node3D = tree_scene.instantiate()
		add_child(tree)
		tree.global_position = pos
		tree.rotation.y = rng.randf_range(0.0, TAU)
		var scale_factor: float = rng.randf_range(0.8, 1.3)
		tree.scale = Vector3(scale_factor, scale_factor, scale_factor)
		var trunk_body := StaticBody3D.new()
		tree.add_child(trunk_body)
		var collision := CollisionShape3D.new()
		trunk_body.add_child(collision)
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.28
		cylinder.height = 4.5
		collision.shape = cylinder
		collision.position = Vector3(0.0, 2.25, 0.0)


func _spawn_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99821
	var bush_scenes: Array = BUSH_SCENES
	for _attempt in range(30):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(8.0, 85.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if abs(pos.x) > 94.0 or abs(pos.z) > 94.0:
			continue
		var bush_scene: PackedScene = bush_scenes[rng.randi_range(0, bush_scenes.size() - 1)]
		var bush: Node3D = bush_scene.instantiate()
		add_child(bush)
		bush.global_position = pos
		bush.rotation.y = rng.randf_range(0.0, TAU)
		var scale_factor: float = rng.randf_range(0.7, 1.2)
		bush.scale = Vector3(scale_factor, scale_factor, scale_factor)


func _spawn_initial_enemies() -> void:
	for pos in ENEMY_SPAWN_POSITIONS:
		_spawn_enemy_at(pos)


func _spawn_enemy_at(pos: Vector3) -> void:
	var enemy: BasicEnemy = BasicEnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.died.connect(_on_enemy_died.bind(pos))


func _on_enemy_died(xp: int, pos: Vector3) -> void:
	player.add_xp(xp)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_spawn_enemy_at(pos)


func _spawn_sunflowers() -> void:
	var positions: Array[Vector3] = [
		Vector3(5.0, 0.0, 3.0),
		Vector3(-8.0, 0.0, -6.0),
	]
	for pos in positions:
		var pickup: SunflowerPickup = SunflowerPickupScene.instantiate()
		add_child(pickup)
		pickup.global_position = pos


func _build_dock() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.26, 0.1)
	_add_box_mesh(Vector3(6.0, 0.3, 4.0), Vector3(0.0, 0.15, 90.0), wood)
	_add_box_mesh(Vector3(0.3, 1.5, 0.3), Vector3(-2.5, 0.75, 91.5), wood)
	_add_box_mesh(Vector3(0.3, 1.5, 0.3), Vector3(2.5, 0.75, 91.5), wood)
	_add_box_mesh(Vector3(6.0, 0.15, 0.15), Vector3(0.0, 1.5, 91.5), wood)
	var label := Label3D.new()
	add_child(label)
	label.global_position = Vector3(0.0, 2.2, 91.0)
	label.text = "South Cove"
	label.font_size = 48
	label.modulate = Color(0.9, 0.85, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _add_box_mesh(size: Vector3, pos: Vector3, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	add_child(mesh_instance)
	mesh_instance.position = pos


func _setup_south_cove_trigger() -> void:
	var trigger := Area3D.new()
	trigger.name = "SouthCoveTrigger"
	add_child(trigger)
	trigger.position = Vector3(0.0, 1.0, 91.0)
	var collision := CollisionShape3D.new()
	trigger.add_child(collision)
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 4.0)
	collision.shape = box
	trigger.body_entered.connect(_on_south_cove_entered)


func _on_south_cove_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("ZONE: South Cove — scene transition goes here")


func _build_campfire_fx() -> void:
	var campfire: Node3D = $Campfire
	var flame_mesh: Node = campfire.get_node_or_null("FlameMesh")
	if flame_mesh:
		flame_mesh.queue_free()

	var fire_particles := GPUParticles3D.new()
	fire_particles.name = "FireParticles"
	campfire.add_child(fire_particles)
	fire_particles.position = Vector3(0.0, 0.3, 0.0)
	fire_particles.amount = 24
	fire_particles.lifetime = 0.6
	fire_particles.explosiveness = 0.0
	fire_particles.randomness = 0.5
	fire_particles.emitting = true

	var fire_process := ParticleProcessMaterial.new()
	fire_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_process.emission_sphere_radius = 0.12
	fire_process.direction = Vector3(0.0, 1.0, 0.0)
	fire_process.spread = 18.0
	fire_process.gravity = Vector3(0.0, 0.5, 0.0)
	fire_process.initial_velocity_min = 1.2
	fire_process.initial_velocity_max = 2.2
	fire_process.scale_min = 0.12
	fire_process.scale_max = 0.28
	fire_process.color = Color(1.0, 0.55, 0.05, 1.0)
	var fire_gradient := Gradient.new()
	fire_gradient.add_point(0.0, Color(1.0, 0.9, 0.2, 1.0))
	fire_gradient.add_point(0.5, Color(1.0, 0.3, 0.0, 0.6))
	fire_gradient.add_point(1.0, Color(0.2, 0.1, 0.0, 0.0))
	var fire_gradient_tex := GradientTexture1D.new()
	fire_gradient_tex.gradient = fire_gradient
	fire_process.color_ramp = fire_gradient_tex
	fire_particles.process_material = fire_process

	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(0.25, 0.25)
	var fire_draw_mat := StandardMaterial3D.new()
	fire_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_draw_mat.albedo_color = Color(1.0, 0.6, 0.1, 0.9)
	fire_draw_mat.emission_enabled = true
	fire_draw_mat.emission = Color(1.0, 0.4, 0.0, 1.0)
	fire_draw_mat.emission_energy_multiplier = 3.0
	fire_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_draw_mat.vertex_color_use_as_albedo = true
	fire_quad.material = fire_draw_mat
	fire_particles.draw_pass_1 = fire_quad

	var smoke_particles := GPUParticles3D.new()
	smoke_particles.name = "SmokeParticles"
	campfire.add_child(smoke_particles)
	smoke_particles.position = Vector3(0.0, 1.2, 0.0)
	smoke_particles.amount = 16
	smoke_particles.lifetime = 2.5
	smoke_particles.explosiveness = 0.0
	smoke_particles.randomness = 0.8
	smoke_particles.emitting = true

	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_process.emission_sphere_radius = 0.08
	smoke_process.direction = Vector3(0.0, 1.0, 0.0)
	smoke_process.spread = 30.0
	smoke_process.gravity = Vector3(0.0, 0.15, 0.0)
	smoke_process.initial_velocity_min = 0.4
	smoke_process.initial_velocity_max = 0.9
	smoke_process.scale_min = 0.3
	smoke_process.scale_max = 0.7
	var smoke_gradient := Gradient.new()
	smoke_gradient.add_point(0.0, Color(0.4, 0.35, 0.3, 0.35))
	smoke_gradient.add_point(0.6, Color(0.5, 0.45, 0.42, 0.15))
	smoke_gradient.add_point(1.0, Color(0.6, 0.58, 0.56, 0.0))
	var smoke_gradient_tex := GradientTexture1D.new()
	smoke_gradient_tex.gradient = smoke_gradient
	smoke_process.color_ramp = smoke_gradient_tex
	smoke_particles.process_material = smoke_process

	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.5, 0.5)
	var smoke_draw_mat := StandardMaterial3D.new()
	smoke_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_draw_mat.albedo_color = Color(0.5, 0.45, 0.4, 0.3)
	smoke_draw_mat.vertex_color_use_as_albedo = true
	smoke_quad.material = smoke_draw_mat
	smoke_particles.draw_pass_1 = smoke_quad

	var log_material := StandardMaterial3D.new()
	log_material.albedo_color = Color(0.22, 0.12, 0.05)
	for angle_deg in [0, 90, 180, 270]:
		var angle_rad: float = deg_to_rad(float(angle_deg))
		var log_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.08
		cylinder.bottom_radius = 0.1
		cylinder.height = 1.0
		log_mesh.mesh = cylinder
		log_mesh.material_override = log_material
		campfire.add_child(log_mesh)
		log_mesh.position = Vector3(cos(angle_rad) * 0.3, 0.06, sin(angle_rad) * 0.3)
		log_mesh.rotation.z = deg_to_rad(90.0)


func _apply_ground_shader() -> void:
	var ground_mesh: MeshInstance3D = $Ground/MeshInstance3D
	var shader := Shader.new()
	shader.code = """shader_type spatial;

uniform vec4 color_a : source_color = vec4(0.18, 0.42, 0.10, 1.0);
uniform vec4 color_b : source_color = vec4(0.28, 0.55, 0.18, 1.0);
uniform vec4 color_dirt : source_color = vec4(0.32, 0.22, 0.10, 1.0);
uniform float noise_scale : hint_range(0.01, 0.2) = 0.04;
uniform float dirt_radius : hint_range(1.0, 20.0) = 8.0;

float hash(vec2 p) {
\treturn fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
\tvec2 i = floor(p);
\tvec2 f = fract(p);
\tf = f * f * (3.0 - 2.0 * f);
\treturn mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
\t           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

void fragment() {
\tvec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
\tfloat n = noise(world_pos.xz * noise_scale);
\tfloat n2 = noise(world_pos.xz * noise_scale * 3.0 + vec2(5.3, 1.7));
\tfloat blend = clamp(n * 0.7 + n2 * 0.3, 0.0, 1.0);
\tvec4 grass = mix(color_a, color_b, blend);
\tfloat dist_from_fire = length(world_pos.xz);
\tfloat dirt_blend = 1.0 - smoothstep(dirt_radius * 0.5, dirt_radius, dist_from_fire);
\tALBEDO = mix(grass, color_dirt, dirt_blend).rgb;
\tROUGHNESS = 0.9;
\tMETALLIC = 0.0;
}
"""
	var ground_material := ShaderMaterial.new()
	ground_material.shader = shader
	ground_mesh.material_override = ground_material
