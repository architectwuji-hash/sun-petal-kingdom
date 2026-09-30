## japanese_lake_restaurant.gd
## Atmospheric Japanese lake restaurant — procedural placeholder.
## Built from Godot primitives to match the structure of the original asset
## (boardwalk, tori gate, lanterns, tables, lake platform).
## Replace MeshInstance3D nodes with the Unreal-exported FBX when available.
extends Node3D

## Water surface color
@export var water_color  : Color = Color(0.05, 0.35, 0.55, 0.78)
## Lantern glow color
@export var lantern_glow : Color = Color(1.0, 0.65, 0.1)

const WOOD_COLOR   := Color(0.38, 0.24, 0.12)
const STONE_COLOR  := Color(0.55, 0.52, 0.48)
const ROOF_COLOR   := Color(0.12, 0.1, 0.09)
const PAPER_COLOR  := Color(0.95, 0.9, 0.7)

func _ready() -> void:
	_build()

func _build() -> void:
	# ── Water plane ─────────────────────────────────────────────────────────
	_box(Vector3(0, -0.05, 0), Vector3(20, 0.1, 20), water_color, true)

	# ── Main platform ───────────────────────────────────────────────────────
	_box(Vector3(0, 0.15, 0), Vector3(8, 0.3, 6), WOOD_COLOR)

	# ── Boardwalk extending to shore ────────────────────────────────────────
	for i in 5:
		_box(Vector3(-5.5 - i * 1.0, 0.12, 0), Vector3(0.9, 0.25, 1.8), WOOD_COLOR)

	# ── Restaurant walls and roof ───────────────────────────────────────────
	# Back wall
	_box(Vector3(0, 1.5, -2.8), Vector3(7.5, 3.0, 0.15), WOOD_COLOR)
	# Side walls
	_box(Vector3(-3.65, 1.5, 0), Vector3(0.15, 3.0, 5.5), WOOD_COLOR)
	_box(Vector3( 3.65, 1.5, 0), Vector3(0.15, 3.0, 5.5), WOOD_COLOR)
	# Paper panels (windows)
	for col in [-2.0, 0.0, 2.0]:
		_box(Vector3(col, 1.8, -2.72), Vector3(1.4, 1.8, 0.05), PAPER_COLOR)

	# Pagoda-style roof (two-tier wedge)
	_box(Vector3(0, 3.3, 0), Vector3(8.5, 0.2, 6.5), ROOF_COLOR)  # lower eave
	_box(Vector3(0, 4.1, 0), Vector3(7.0, 0.2, 5.0), ROOF_COLOR)  # upper eave
	_box(Vector3(0, 4.9, 0), Vector3(5.5, 0.2, 3.5), ROOF_COLOR)  # cap

	# ── Tori gate ───────────────────────────────────────────────────────────
	_box(Vector3(-3.0, 1.5, 3.5), Vector3(0.25, 3.0, 0.25), STONE_COLOR)
	_box(Vector3( 3.0, 1.5, 3.5), Vector3(0.25, 3.0, 0.25), STONE_COLOR)
	_box(Vector3( 0.0, 3.2, 3.5), Vector3(6.5, 0.25, 0.3), ROOF_COLOR)  # top beam
	_box(Vector3( 0.0, 2.6, 3.5), Vector3(5.8, 0.18, 0.25), ROOF_COLOR)  # lower beam

	# ── Tables and stools inside ────────────────────────────────────────────
	for tx in [-2.0, 0.0, 2.0]:
		_box(Vector3(tx, 0.55, -1.0), Vector3(1.2, 0.08, 0.8), WOOD_COLOR)  # table
		for sx in [-0.45, 0.45]:
			_box(Vector3(tx + sx, 0.3, -1.0), Vector3(0.3, 0.5, 0.3), WOOD_COLOR)

	# ── Hanging lanterns ────────────────────────────────────────────────────
	for lx in [-2.5, 0.0, 2.5]:
		_lantern(Vector3(lx, 2.7, 0.5))

	# ── Lily pads ───────────────────────────────────────────────────────────
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for _i in 12:
		var lx := rng.randf_range(-8.0, 8.0)
		var lz := rng.randf_range(-8.0, 8.0)
		if abs(lx) < 4.5 and abs(lz) < 3.5:
			continue  # skip platform area
		_box(Vector3(lx, 0.01, lz), Vector3(0.6, 0.03, 0.6),
			Color(0.18, 0.55, 0.18))

func _lantern(pos: Vector3) -> void:
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color           = lantern_glow
	glow_mat.emission_enabled       = true
	glow_mat.emission               = lantern_glow
	glow_mat.emission_energy_multiplier = 2.5
	# Body
	var body := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = 0.14
	cyl.bottom_radius = 0.14
	cyl.height        = 0.28
	body.mesh          = cyl
	body.set_surface_override_material(0, glow_mat)
	body.position      = pos
	add_child(body)
	# Cap
	_box(pos + Vector3(0, 0.2, 0), Vector3(0.32, 0.07, 0.32), ROOF_COLOR)
	# Rope
	_box(pos + Vector3(0, 0.35, 0), Vector3(0.02, 0.3, 0.02), WOOD_COLOR)
	# OmniLight
	var light             := OmniLight3D.new()
	light.position        = pos
	light.light_color     = lantern_glow
	light.light_energy    = 1.4
	light.omni_range      = 4.5
	add_child(light)

func _box(pos: Vector3, size: Vector3, color: Color,
		alpha_hint: bool = false) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.85
	if alpha_hint:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = color.a
	var mi   := MeshInstance3D.new()
	var box  := BoxMesh.new()
	box.size = size
	mi.mesh  = box
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
