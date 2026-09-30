## mysterious_tree.gd
## Procedural Witcher-style twisted dead tree. Drop into any scene.
extends Node3D

@export var bark_color : Color = Color(0.18, 0.12, 0.08)
@export var trunk_height : float = 6.0
@export var num_branches : int = 7

var _mats : Array[StandardMaterial3D] = []

func _ready() -> void:
	_build_tree()

func _build_tree() -> void:
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color    = bark_color
	bark_mat.roughness       = 0.95
	bark_mat.metallic        = 0.0

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color           = Color(0.05, 0.65, 0.3, 0.55)
	glow_mat.emission_enabled       = true
	glow_mat.emission               = Color(0.0, 0.9, 0.35)
	glow_mat.emission_energy_multiplier = 1.8
	glow_mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.roughness              = 0.5

	# ── Trunk ──────────────────────────────────────────────────────────────
	_add_cylinder(Vector3.ZERO, trunk_height, 0.32, 0.14, bark_mat)

	# ── Branches ───────────────────────────────────────────────────────────
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in num_branches:
		var t        := 0.35 + float(i) / num_branches * 0.65
		var base_y   := t * trunk_height
		var angle    := rng.randf() * TAU
		var length   := rng.randf_range(1.5, 3.5)
		var tilt     := rng.randf_range(0.3, 0.7)  # radians from horizontal
		var dir      := Vector3(cos(angle), tan(tilt), sin(angle)).normalized()
		var mid      := Vector3(0, base_y, 0) + dir * length * 0.5
		var mi       := _add_cylinder(mid, length, 0.08, 0.03, bark_mat)
		mi.rotation  = Vector3(
			atan2(dir.y, dir.z) if dir.z != 0 else PI/2,
			-angle,
			0.0
		)

	# ── Glowing root tendrils ───────────────────────────────────────────────
	for i in 5:
		var angle := float(i) / 5.0 * TAU
		var tendril := _add_cylinder(
			Vector3(cos(angle) * 0.4, 0.15, sin(angle) * 0.4),
			0.8, 0.06, 0.02, glow_mat
		)
		tendril.rotation.z = -0.6
		tendril.rotation.y = angle

	# ── Hollow glowing sphere at canopy ────────────────────────────────────
	var orb_mi := MeshInstance3D.new()
	var orb     := SphereMesh.new()
	orb.radius  = 0.35
	orb.height  = 0.70
	orb_mi.mesh = orb
	orb_mi.set_surface_override_material(0, glow_mat)
	orb_mi.position = Vector3(0, trunk_height + 0.1, 0)
	add_child(orb_mi)

	# ── Collision ──────────────────────────────────────────────────────────
	var static_body := StaticBody3D.new()
	static_body.name = "TreeCollision"
	var cs           := CollisionShape3D.new()
	var shape        := CapsuleShape3D.new()
	shape.height     = trunk_height
	shape.radius     = 0.5
	cs.shape         = shape
	cs.position      = Vector3(0, trunk_height * 0.5, 0)
	static_body.add_child(cs)
	add_child(static_body)

func _add_cylinder(pos: Vector3, height: float, r_top: float, r_bot: float,
		mat: Material) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = r_top
	cyl.bottom_radius = r_bot
	cyl.height        = height
	mi.mesh           = cyl
	mi.set_surface_override_material(0, mat)
	mi.position       = pos
	mi.cast_shadow    = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
