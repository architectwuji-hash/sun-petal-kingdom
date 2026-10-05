extends Node3D
## Auros Temple Interior — zone script.
## Builds the temple geometry at runtime, then restores player state
## from SaveManager.scene_transfer_data and places the player at the entrance.

## Player spawn point inside the temple (just past the south entrance)
const ENTRANCE_POSITION := Vector3(0.0, 0.5, 18.0)

## Temple dimensions (half-extents describe the hall)
const HALL_W  := 20.0   # half-width  (total 40 m)
const HALL_H  := 16.0   # full height
const HALL_D  := 25.0   # half-depth  (total 50 m)

# ─── Materials (created once, shared) ────────────────────────────────────────
var _mat_stone  : StandardMaterial3D
var _mat_gold   : StandardMaterial3D
var _mat_floor  : StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_geometry()
	_setup_lighting()

	## Wait one frame so all nodes are initialised before we move the player
	await get_tree().process_frame
	_restore_player()

# ─── Player Restore ───────────────────────────────────────────────────────────

func _restore_player() -> void:
	var player: Node = get_node_or_null("Player3D")
	if player == null:
		push_error("[AurosTempleInterior] Player3D not found!")
		return

	var td: Dictionary = SaveManager.scene_transfer_data
	if not td.is_empty() and td.get("class") == "Player3D":
		var restore := td.duplicate()
		restore["x"] = ENTRANCE_POSITION.x
		restore["y"] = ENTRANCE_POSITION.y
		restore["z"] = ENTRANCE_POSITION.z
		if player.has_method("apply_save_data"):
			player.apply_save_data(restore)
	else:
		player.global_position = ENTRANCE_POSITION

# ─── Materials ────────────────────────────────────────────────────────────────

func _build_materials() -> void:
	_mat_floor = StandardMaterial3D.new()
	_mat_floor.albedo_color = Color(0.78, 0.72, 0.55)
	_mat_floor.roughness = 0.6

	_mat_stone = StandardMaterial3D.new()
	_mat_stone.albedo_color = Color(0.62, 0.58, 0.46)
	_mat_stone.roughness = 0.75

	_mat_gold = StandardMaterial3D.new()
	_mat_gold.albedo_color = Color(1.0, 0.85, 0.2)
	_mat_gold.metallic = 0.8
	_mat_gold.roughness = 0.2
	_mat_gold.emission_enabled = true
	_mat_gold.emission = Color(1.0, 0.7, 0.0)
	_mat_gold.emission_energy_multiplier = 2.0

# ─── Geometry ─────────────────────────────────────────────────────────────────

func _build_geometry() -> void:
	## Floor
	_add_box(Vector3(0, -0.5, 0), Vector3(HALL_W * 2, 1.0, HALL_D * 2), _mat_floor, true)

	## Ceiling
	_add_box(Vector3(0, HALL_H + 0.5, 0), Vector3(HALL_W * 2, 1.0, HALL_D * 2), _mat_stone, true)

	## Walls (N/S/E/W)
	_add_box(Vector3(0, HALL_H * 0.5, -HALL_D - 0.5), Vector3(HALL_W * 2, HALL_H, 1.0), _mat_stone, true)
	_add_box(Vector3(0, HALL_H * 0.5, HALL_D + 0.5),  Vector3(HALL_W * 2, HALL_H, 1.0), _mat_stone, true)
	_add_box(Vector3(-HALL_W - 0.5, HALL_H * 0.5, 0), Vector3(1.0, HALL_H, HALL_D * 2), _mat_stone, true)
	_add_box(Vector3( HALL_W + 0.5, HALL_H * 0.5, 0), Vector3(1.0, HALL_H, HALL_D * 2), _mat_stone, true)

	## Sun Altar — raised platform in the north half
	_add_box(Vector3(0, 1.0, -10), Vector3(6, 2.0, 6), _mat_stone, true)

	## Sun Orb atop altar — glowing sphere
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	orb.mesh = sphere
	orb.material_override = _mat_gold
	orb.position = Vector3(0, 3.6, -10)
	add_child(orb)
	_orb_node = orb

	## Columns (4 pairs)
	var col_x := [10.0, -10.0]
	var col_z := [-8.0, 0.0, 8.0]
	for cx in col_x:
		for cz in col_z:
			_add_column(Vector3(cx, HALL_H * 0.5, cz))

	## Golden decorative strips along the floor edge
	_add_box(Vector3(0, 0.05, -HALL_D + 0.5), Vector3(HALL_W * 2, 0.1, 0.4), _mat_gold, false)
	_add_box(Vector3(0, 0.05,  HALL_D - 0.5), Vector3(HALL_W * 2, 0.1, 0.4), _mat_gold, false)

func _add_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D, with_collision: bool) -> void:
	var mesh_inst := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_inst.mesh = bm
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	add_child(mesh_inst)

	if with_collision:
		var body := StaticBody3D.new()
		body.position = pos
		add_child(body)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)

func _add_column(pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.65
	cyl.height = HALL_H
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _mat_stone
	mesh_inst.position = pos
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = HALL_H
	shape.radius = 0.65
	col.shape = shape
	body.add_child(col)

# ─── Lighting ─────────────────────────────────────────────────────────────────

func _setup_lighting() -> void:
	## Warm directional light simulating a skylight
	var dir := DirectionalLight3D.new()
	dir.transform = Transform3D(
		Vector3(0.866, 0, 0.5), Vector3(0.25, 0.866, -0.433),
		Vector3(-0.433, 0.5, 0.75), Vector3(0, 30, 0))
	dir.light_color = Color(1.0, 0.95, 0.78)
	dir.light_energy = 0.7
	dir.shadow_enabled = true
	add_child(dir)

	## Fill ambient from above
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 14, 0)
	fill.light_color = Color(1.0, 0.88, 0.6)
	fill.light_energy = 0.4
	fill.omni_range = 90.0
	add_child(fill)

	## Sun orb glow light at the altar
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 4.0, -10)
	glow.light_color = Color(1.0, 0.85, 0.3)
	glow.light_energy = 4.0
	glow.omni_range = 30.0
	add_child(glow)
	_orb_light = glow

	## Entrance torches
	for side in [-8.0, 8.0]:
		var torch := OmniLight3D.new()
		torch.position = Vector3(side, 2.5, 22)
		torch.light_color = Color(1.0, 0.6, 0.2)
		torch.light_energy = 2.0
		torch.omni_range = 12.0
		add_child(torch)

# ─── Ambient Sun Orb Animation ────────────────────────────────────────────────

var _orb_node: MeshInstance3D = null
var _orb_light: OmniLight3D = null
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_orb_node):
		_orb_node.rotation.y = _t * 0.4
		var pulse: float = 1.0 + 0.15 * sin(_t * 2.0)
		_orb_node.scale = Vector3(pulse, pulse, pulse)
	if is_instance_valid(_orb_light):
		_orb_light.light_energy = 3.5 + 1.0 * sin(_t * 2.0)
