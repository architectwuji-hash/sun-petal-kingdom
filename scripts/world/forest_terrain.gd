@tool
extends Node3D
class_name ForestTerrain
## Procedural fantasy-forest map.
## Generates rolling hills, a central clearing, two dirt paths, and scatters the
## Quaternius nature pack (trees, bushes, rocks, flowers, grass) across it.
## Everything is rebuilt from `terrain_seed`, so the same seed = the same map
## in the editor and in-game. To make the map bigger, just raise `map_size`.

const CELL := 1.5
const CHUNK := 50.0   # size of each draw tile (metres)
const NATURE := "res://assets/models/nature/"

const TREES := {
	"PineTree_1.glb": 3, "PineTree_2.glb": 3, "PineTree_3.glb": 2, "PineTree_4.glb": 3, "PineTree_5.glb": 3,
	"NormalTree_1.glb": 2, "NormalTree_2.glb": 2, "NormalTree_3.glb": 2, "NormalTree_4.glb": 2, "NormalTree_5.glb": 1,
	"MapleTree_1.gltf": 2, "MapleTree_2.gltf": 2, "MapleTree_4.gltf": 1, "MapleTree_5.gltf": 2,
	"BirchTree_1.gltf": 2, "BirchTree_2.gltf": 2, "BirchTree_3.gltf": 1, "BirchTree_4.gltf": 1, "BirchTree_5.gltf": 1,
}
const DEAD_TREES := ["DeadTree_1.gltf", "DeadTree_2.gltf", "DeadTree_3.gltf", "DeadTree_5.gltf", "DeadTree_6.gltf", "DeadTree_9.gltf"]
const BUSHES := ["Bush.gltf", "Bush_Large.gltf", "Bush_Small.gltf", "Bush_Flowers.gltf", "Bush_Large_Flowers.gltf", "Bush_Small_Flowers.gltf", "Plant_1.glb", "Plant_2.glb", "Plant_Flowers.glb"]
const ROCKS := ["Rock_1.glb", "Rock_2.glb", "Rock_3.glb", "Rock_4.glb", "Rock_5.glb"]
const FLOWERS := ["Flower_1_Clump.gltf", "Flower_2_Clump.gltf", "Flower_3_Clump.gltf", "Flower_4_Clump.gltf", "Flower_5_Clump.gltf", "Flower_1.gltf", "Flower_2.gltf"]
const GRASS := ["Grass_Large.gltf", "Grass_Small.gltf", "Grass_Large_Extruded.gltf"]

# --- Tree harvesting (runtime only) ---
# Stump + log models are Kenney's Castle Kit pieces already in the project.
const LOG_SCENE := preload("res://assets/models/buildings/kenney_castle/tree-log.glb")
const STUMP_SCENE := preload("res://assets/models/buildings/kenney_castle/tree-trunk.glb")
const TREE_HITS := 4          # axe hits to fell a tree
const WOOD_PER_TREE := 5      # logs dropped per tree (+1 wood each)
const REGROW_TIME := 60.0     # seconds until a felled tree grows back
const LOG_PICKUP_DELAY := 0.8 # logs can't be grabbed until they've landed
const FRUIT_TREE_CHANCE := 0.18  # fraction of trees that bear fruit

const COL_MEADOW := Color(0.33, 0.50, 0.21)
const COL_FOREST := Color(0.17, 0.30, 0.12)
const COL_DIRT := Color(0.46, 0.34, 0.21)
const COL_ROCK := Color(0.33, 0.35, 0.29)

## How far away each kind of prop is still drawn. Lower = faster.
@export var tree_draw_distance: float = 90.0
@export var decor_draw_distance: float = 50.0
@export var grass_draw_distance: float = 30.0
@export var map_size: int = 600:
	set(v):
		map_size = maxi(30, v)
		_queue_regen()
@export var terrain_seed: int = 2026:
	set(v):
		terrain_seed = v
		_queue_regen()
@export var hill_height: float = 5.0:
	set(v):
		hill_height = v
		_queue_regen()
@export var clearing_radius: float = 14.0:
	set(v):
		clearing_radius = v
		_queue_regen()
@export_range(0.0, 3.0) var tree_density: float = 1.0:
	set(v):
		tree_density = v
		_queue_regen()
@export_range(0.0, 3.0) var decor_density: float = 1.0:
	set(v):
		decor_density = v
		_queue_regen()
@export_range(0.0, 3.0) var grass_density: float = 1.0:
	set(v):
		grass_density = v
		_queue_regen()
@export var sun_motes: bool = true:
	set(v):
		sun_motes = v
		_queue_regen()
## Drops the player / enemies placed in the scene onto the ground when the game starts.
@export var snap_characters_on_start: bool = true
## Tick this in the Inspector to rebuild the map.
@export var regenerate: bool = false:
	set(_v):
		_queue_regen()

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _root: Node3D = null
var _regen_pending := false
var _part_cache: Dictionary = {}
var _mm_parts: Dictionary = {}   # model -> {offsets, lookup (global idx -> [chunk, local idx]), chunks}
var _harvest: Array = []         # one Dictionary per choppable tree


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("harvestable_trees")
	_generate()
	if not Engine.is_editor_hint() and snap_characters_on_start:
		_snap_characters()
		_snap_buildings()


func _queue_regen() -> void:
	if not is_inside_tree() or _regen_pending:
		return
	_regen_pending = true
	call_deferred("_generate")


# ── HEIGHT / MASKS (public so other scripts can ask "how high is the ground here?") ──

func _setup_noise() -> void:
	_noise.seed = terrain_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_detail.seed = terrain_seed + 11
	_detail.frequency = 0.09
	_forest.seed = terrain_seed + 23
	_forest.frequency = 0.035


func height_at(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := n * hill_height + _detail.get_noise_2d(x, z) * 0.25
	# Flat clearing in the middle (spawn / fight arena)
	var r := Vector2(x, z).length()
	h = lerpf(hill_height * 0.45, h, smoothstep(clearing_radius, clearing_radius + 10.0, r))
	# Flat clearing for Japanese Lake Restaurant (A1 quadrant, -100,-100)
	var r_rest := Vector2(x + 100.0, z + 100.0).length()
	h = lerpf(0.0, h, smoothstep(14.0, 26.0, r_rest))
	# Paths sink slightly into the ground
	h -= path_mask(x, z) * 0.3
	# Ridge around the border so the map feels enclosed
	var half := map_size * 0.5
	var edge := maxf(absf(x), absf(z))
	var e := smoothstep(half - 14.0, half, edge)
	h += e * e * hill_height * 2.2
	return h


func path_mask(x: float, z: float) -> float:
	var off := float(terrain_seed % 100)
	# North–south path
	var cx := sin(z * 0.045 + off) * 9.0 + sin(z * 0.11 + off * 2.0) * 3.0
	var a := 1.0 - smoothstep(1.3, 2.8, absf(x - cx))
	# East–west path
	var cz := sin(x * 0.05 + off * 3.0) * 8.0 + sin(x * 0.13) * 2.5
	var b := 1.0 - smoothstep(1.3, 2.8, absf(z - cz))
	return maxf(a, b)


func forest_amount(x: float, z: float) -> float:
	var f := smoothstep(-0.45, 0.15, _forest.get_noise_2d(x, z))
	var half := map_size * 0.5
	var edge := maxf(absf(x), absf(z))
	return clampf(f + smoothstep(half - 20.0, half - 6.0, edge), 0.0, 1.0)


# ── GENERATION ────────────────────────────────────────────────────────────────

func _generate() -> void:
	_regen_pending = false
	if not is_inside_tree():
		return
	_setup_noise()
	_harvest.clear()
	_mm_parts.clear()
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "_Generated"
	add_child(_root)  # no owner => never saved into the .tscn, rebuilt on load
	_build_ground()
	_build_walls()
	_scatter()
	if sun_motes:
		_build_motes()
	_build_village_beacon()



# ── VILLAGE BEACON ────────────────────────────────────────────────────────────
## Tall glowing pillar marking Suji Village — visible anywhere in the editor
## and in-game.  Remove once the village has a permanent landmark prop.
func _build_village_beacon() -> void:
	const VX := 195.0
	const VZ := 95.0
	const POLE_H  := 60.0
	const POLE_R  := 0.4
	const ORB_R   := 2.5

	var ground_y := height_at(VX, VZ)

	# Bright orange emissive material shared by pole and orb
	var mat := StandardMaterial3D.new()
	mat.albedo_color          = Color(1.0, 0.55, 0.05)
	mat.emission_enabled      = true
	mat.emission              = Color(1.0, 0.55, 0.05)
	mat.emission_energy_multiplier = 4.0

	# Pole
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius    = POLE_R
	pole_mesh.bottom_radius = POLE_R
	pole_mesh.height        = POLE_H
	var pole := MeshInstance3D.new()
	pole.name = "SujiVillageBeacon_Pole"
	pole.mesh = pole_mesh
	pole.material_override = mat
	pole.position = Vector3(VX, ground_y + POLE_H * 0.5, VZ)
	_root.add_child(pole)

	# Orb on top
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = ORB_R
	orb_mesh.height = ORB_R * 2.0
	var orb := MeshInstance3D.new()
	orb.name = "SujiVillageBeacon_Orb"
	orb.mesh = orb_mesh
	orb.material_override = mat
	orb.position = Vector3(VX, ground_y + POLE_H + ORB_R, VZ)
	_root.add_child(orb)

	# Omni light so the orb glows in the scene
	var light := OmniLight3D.new()
	light.name = "SujiVillageBeacon_Light"
	light.light_color  = Color(1.0, 0.65, 0.2)
	light.light_energy = 8.0
	light.omni_range   = 30.0
	light.position = Vector3(VX, ground_y + POLE_H + ORB_R, VZ)
	_root.add_child(light)

func _build_ground() -> void:
	var n := int(map_size / CELL) + 1
	var half := map_size * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(-half + i * CELL, -half + j * CELL)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var x := -half + i * CELL
			var z := -half + j * CELL
			var h := heights[j * n + i]
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			var nrm := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			var k := j * n + i
			verts[k] = Vector3(x, h, z)
			norms[k] = nrm
			uvs[k] = Vector2(x, z) * 0.1
			# Ground colour: meadow -> forest floor, rocky on slopes, dirt on paths
			var c := COL_MEADOW.lerp(COL_FOREST, forest_amount(x, z))
			var v := _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.06
			c = Color(c.r + v, c.g + v * 1.3, c.b + v * 0.5)
			c = c.lerp(COL_ROCK, smoothstep(0.75, 0.5, nrm.y) * 0.8)
			c = c.lerp(COL_DIRT, path_mask(x, z) * 0.9)
			cols[k] = c

	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c2 := a + n
			var d := c2 + 1
			idx.append_array(PackedInt32Array([a, b, c2, b, d, c2]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	# Ground receives shadows but doesn't cast them - skips re-drawing the
	# whole 600 m terrain into the shadow map every frame.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	# Scale body so each HeightMapShape3D cell = CELL units (1.5), matching the visual mesh
	body.scale = Vector3(CELL, 1.0, CELL)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	_root.add_child(body)


func _build_walls() -> void:
	var half := map_size * 0.5
	var body := StaticBody3D.new()
	body.name = "BorderWalls"
	for side in 4:
		var box := BoxShape3D.new()
		box.size = Vector3(map_size + 2.0, 60.0, 1.0) if side < 2 else Vector3(1.0, 60.0, map_size + 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = box
		match side:
			0: cs.position = Vector3(0, 20, -half - 0.5)
			1: cs.position = Vector3(0, 20, half + 0.5)
			2: cs.position = Vector3(-half - 0.5, 20, 0)
			3: cs.position = Vector3(half + 0.5, 20, 0)
		body.add_child(cs)
	_root.add_child(body)


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var half := map_size * 0.5 - 1.5
	var area_scale := float(map_size * map_size) / 20000.0  # 1.0 at 100x100
	var buckets: Dictionary = {}   # model file -> Array[Transform3D]
	var shadowless: Dictionary = {}
	var colliders := StaticBody3D.new()
	colliders.name = "PropCollision"
	_root.add_child(colliders)

	# --- Trees (spaced out, avoid clearing + paths) ---
	var tree_pool: Array = []
	for k in TREES:
		for _w in TREES[k]:
			tree_pool.append(k)
	var placed_count := 0
	var want := int(400 * area_scale * tree_density)
	var tries := 0
	# Spatial grid (cell > sqrt(6.5) ≈ 2.55) keeps placement O(n) at any map size.
	var tree_grid: Dictionary = {}
	while placed_count < want and tries < want * 25:
		tries += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < clearing_radius + 3.0 or path_mask(x, z) > 0.05 or Vector2(x + 100.0, z + 100.0).length() < 20.0:
			continue
		if rng.randf() > forest_amount(x, z) * 0.9 + 0.1:
			continue
		var p := Vector2(x, z)
		var gx := floori(p.x / 3.0)
		var gz := floori(p.y / 3.0)
		var ok := true
		for ddx in [-1, 0, 1]:
			if not ok: break
			for ddz in [-1, 0, 1]:
				var nb := Vector2i(gx + ddx, gz + ddz)
				for q in tree_grid.get(nb, []):
					if p.distance_squared_to(q) < 6.5:
						ok = false
						break
		if not ok:
			continue
		placed_count += 1
		var gcell := Vector2i(gx, gz)
		if not tree_grid.has(gcell):
			tree_grid[gcell] = []
		tree_grid[gcell].append(p)
		var s := rng.randf_range(0.8, 1.25)
		var tree_model: String = tree_pool[rng.randi() % tree_pool.size()]
		_add(buckets, tree_model, x, z, s, rng)
		_register_tree(buckets, tree_model, x, z, s, _add_cylinder(colliders, x, z, 0.35 * s, 3.5))
		_maybe_add_fruit_tree(x, z, rng)

	# --- Dead trees (a few eerie ones) ---
	for _i in int(14 * area_scale * decor_density):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < clearing_radius + 3.0 or path_mask(x, z) > 0.05 or Vector2(x + 100.0, z + 100.0).length() < 20.0:
			continue
		var ds := rng.randf_range(0.8, 1.1)
		var dead_model: String = DEAD_TREES[rng.randi() % DEAD_TREES.size()]
		_add(buckets, dead_model, x, z, ds, rng)
		_register_tree(buckets, dead_model, x, z, ds, _add_cylinder(colliders, x, z, 0.3, 3.0))

	# --- Rocks (collidable) ---
	for _i in int(50 * area_scale * decor_density):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < clearing_radius - 2.0 or path_mask(x, z) > 0.2:
			continue
		var s := rng.randf_range(0.7, 1.6)
		_add(buckets, ROCKS[rng.randi() % ROCKS.size()], x, z, s, rng)
		var sph := SphereShape3D.new()
		sph.radius = 0.5 * s
		var cs := CollisionShape3D.new()
		cs.shape = sph
		cs.position = Vector3(x, height_at(x, z) + 0.3 * s, z)
		colliders.add_child(cs)

	# --- Bushes & plants (hug the forest edges) ---
	for _i in int(190 * area_scale * decor_density):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if Vector2(x, z).length() < clearing_radius - 3.0 or path_mask(x, z) > 0.1:
			continue
		var f := forest_amount(x, z)
		if rng.randf() > 0.25 + f * 0.75:
			continue
		_add(buckets, BUSHES[rng.randi() % BUSHES.size()], x, z, rng.randf_range(0.8, 1.4), rng)

	# --- Flowers (mostly meadows + clearing) ---
	for _i in int(420 * area_scale * decor_density):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if path_mask(x, z) > 0.1:
			continue
		if rng.randf() < forest_amount(x, z) * 0.8:
			continue
		var fk: String = FLOWERS[rng.randi() % FLOWERS.size()]
		_add(buckets, fk, x, z, rng.randf_range(0.9, 1.5), rng)
		shadowless[fk] = true

	# --- Grass tufts everywhere ---
	for _i in int(1400 * area_scale * grass_density):
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if path_mask(x, z) > 0.3:
			continue
		var gk: String = GRASS[rng.randi() % GRASS.size()]
		_add(buckets, gk, x, z, rng.randf_range(0.8, 1.6), rng)
		shadowless[gk] = true

	for model in buckets:
		_build_multimesh(model, buckets[model], not shadowless.has(model))


func _add(buckets: Dictionary, model: String, x: float, z: float, s: float, rng: RandomNumberGenerator) -> void:
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, height_at(x, z) - 0.05, z))
	if not buckets.has(model):
		buckets[model] = []
	buckets[model].append(t)


func _add_cylinder(parent: Node3D, x: float, z: float, radius: float, height: float) -> CollisionShape3D:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position = Vector3(x, height_at(x, z) + height * 0.5, z)
	parent.add_child(cs)
	return cs


func _build_multimesh(model: String, xforms: Array, shadows: bool) -> void:
	# The map is split into CHUNK-sized tiles, one MultiMesh per tile per model
	# part. Each tile gets a visibility range, so Godot only draws (and only
	# renders shadows for) the tiles near the camera instead of the whole
	# 600 m forest every frame.
	var parts := _get_parts(model)
	var draw_dist := _draw_distance(model)
	var by_chunk: Dictionary = {}   # Vector2i -> Array[int] (global indices)
	var lookup: Array = []
	lookup.resize(xforms.size())
	for k in xforms.size():
		var o: Vector3 = (xforms[k] as Transform3D).origin
		var key := Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK))
		if not by_chunk.has(key):
			by_chunk[key] = []
		lookup[k] = [key, by_chunk[key].size()]
		by_chunk[key].append(k)
	var entry := {"offsets": [], "lookup": lookup, "chunks": {}}
	for part in parts:
		entry["offsets"].append(part[1])
	for key in by_chunk:
		var ids: Array = by_chunk[key]
		var mms: Array = []
		for pi in parts.size():
			var part: Array = parts[pi]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = ids.size()
			for li in ids.size():
				mm.set_instance_transform(li, (xforms[ids[li]] as Transform3D) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_p%d_%d_%d" % [model.get_basename(), pi, key.x, key.y]
			mmi.set_meta("chunk_center", Vector2((key.x + 0.5) * CHUNK, (key.y + 0.5) * CHUNK))
			mmi.multimesh = mm
			mmi.visibility_range_end = draw_dist
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(mmi)
			mms.append(mm)
		entry["chunks"][key] = mms
	_mm_parts[model] = entry


func _draw_distance(model: String) -> float:
	if TREES.has(model) or DEAD_TREES.has(model):
		return tree_draw_distance
	if GRASS.has(model):
		return grass_draw_distance
	if FLOWERS.has(model):
		return grass_draw_distance * 1.4
	return decor_draw_distance


## Pulls every mesh (and its local offset) out of an imported model, and swaps
## blended leaf materials for alpha-scissor so leaves sort and shadow correctly.
func _get_parts(model: String) -> Array:
	if _part_cache.has(model):
		return _part_cache[model]
	var parts: Array = []
	var ps := load(NATURE + model) as PackedScene
	if ps == null:
		push_warning("ForestTerrain: could not load " + model + " (still importing? tick Regenerate)")
		return parts
	var inst := ps.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect(inst, meshes)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var t := mi.transform
		var p := mi.get_parent()
		while p != null and p != inst:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var mesh := mi.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var bm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					bm.alpha_scissor_threshold = 0.5
				bm.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.surface_set_material(s, bm)
		parts.append([mesh, t])
	inst.free()
	_part_cache[model] = parts
	return parts


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _build_motes() -> void:
	# Drifting golden "sun petal" motes — cheap fantasy atmosphere.
	var p := CPUParticles3D.new()
	p.name = "SunMotes"
	p.amount = int(180 * float(map_size * map_size) / 10000.0)
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(map_size * 0.45, 2.5, map_size * 0.45)
	p.position = Vector3(0, hill_height * 0.5 + 2.5, 0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.35, 0.0))
	grad.set_color(1, Color(1.0, 0.85, 0.35, 0.0))
	grad.add_point(0.3, Color(1.0, 0.9, 0.45, 1.0))
	grad.add_point(0.7, Color(1.0, 0.8, 0.3, 1.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	var glow := Gradient.new()
	glow.set_color(0, Color(1, 1, 1, 1))
	glow.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = glow
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	q.material = m
	p.mesh = q
	_root.add_child(p)


func _snap_characters() -> void:
	var half := map_size * 0.5 - 2.0
	for n in get_parent().get_children():
		if n is CharacterBody3D:
			var c := n as CharacterBody3D
			var pos := c.global_position
			pos.x = clampf(pos.x, -half, half)
			pos.z = clampf(pos.z, -half, half)
			pos.y = height_at(pos.x, pos.z) + 0.3
			c.global_position = pos

## Snaps ruined-cottage instances to terrain height so they never float.
## Matches any node whose name starts with "ruined_stone_cottage".
func _snap_buildings() -> void:
	for n in get_parent().get_children():
		if n is Node3D and n.name.begins_with("ruined_stone_cottage"):
			var b := n as Node3D
			var pos := b.global_position
			pos.y = height_at(pos.x, pos.z)
			b.global_position = pos


# ════════════════════════════════════════════════════════════════════════════
#  Tree harvesting
#  Trees are drawn in MultiMesh batches, so a "tree" here is just an index into
#  its model's batch. Felling one hides that single instance (zero scale) and
#  disables its collision cylinder; regrowing restores both.
# ════════════════════════════════════════════════════════════════════════════

func _register_tree(buckets: Dictionary, model: String, x: float, z: float, s: float, shape: CollisionShape3D) -> void:
	var idx: int = buckets[model].size() - 1
	_harvest.append({
		"model": model, "idx": idx, "xform": buckets[model][idx], "shape": shape,
		"pos": Vector3(x, height_at(x, z), z), "scale": s,
		"hp": TREE_HITS, "felled": false, "busy": false, "stump": null,
	})


## Randomly makes this tree position a fruit-pickup interactable (~FRUIT_TREE_CHANCE chance).
## The node lives at tree ground position so _try_interact()'s distance check works normally.
func _maybe_add_fruit_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
	if rng.randf() > FRUIT_TREE_CHANCE:
		return
	var y := height_at(x, z)
	var fruit_node := Node3D.new()
	fruit_node.name = "FruitTree"
	fruit_node.position = Vector3(x, y, z)

	# Floating prompt label above canopy
	var lbl := Label3D.new()
	lbl.text = "[E] Pick Fruit \U0001F34A"
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 5.0, 0)
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.85, 0.3)
	fruit_node.add_child(lbl)

	_root.add_child(fruit_node)
	fruit_node.add_to_group("interactable")

	fruit_node.set_meta("_interact_callable", func(player: Node) -> void:
		player.add_item("fruit")
		# Remove from interactable group while on cooldown
		fruit_node.remove_from_group("interactable")
		lbl.visible = false
		# Respawn fruit after 2 minutes
		fruit_node.get_tree().create_timer(120.0).timeout.connect(func() -> void:
			if is_instance_valid(fruit_node):
				lbl.visible = true
				fruit_node.add_to_group("interactable")
		)
	)


## Called by the player's axe swing. Damages the closest standing tree within
## `reach` (flat distance) of `point`. Returns true if a tree was hit.
func chop_at(point: Vector3, reach: float, chopper: Node3D) -> bool:
	if Engine.is_editor_hint():
		return false
	var best: Dictionary = {}
	var best_d := reach * reach
	for t in _harvest:
		if t["felled"]:
			continue
		var tp: Vector3 = t["pos"]
		var d := Vector2(tp.x - point.x, tp.z - point.z).length_squared()
		if d < best_d:
			best_d = d
			best = t
	if best.is_empty():
		return false
	best["hp"] -= 1
	_spawn_chips((best["pos"] as Vector3) + Vector3(0, 1.0, 0))
	if best["hp"] <= 0:
		_fell_tree(best, chopper)
	else:
		_shake_tree(best, chopper)
	return true



## Returns the world position of the nearest standing tree within max_radius of `from`.
## Returns Vector3(INF, INF, INF) when no tree is found.
## Called by Tottie and other creatures to find a tree to eat.
func get_nearest_tree_pos(from: Vector3, max_radius: float) -> Vector3:
	var best_pos := Vector3(INF, INF, INF)
	var best_d := max_radius * max_radius
	for t in _harvest:
		if t["felled"]:
			continue
		var tp: Vector3 = t["pos"]
		var d := (Vector2(tp.x - from.x, tp.z - from.z)).length_squared()
		if d < best_d:
			best_d = d
			best_pos = tp
	return best_pos

func _set_tree_xform(tree: Dictionary, xf: Transform3D) -> void:
	var entry: Dictionary = _mm_parts.get(tree["model"], {})
	if entry.is_empty():
		return
	var loc: Array = entry["lookup"][tree["idx"]]
	var mms: Array = entry["chunks"][loc[0]]
	for i in mms.size():
		(mms[i] as MultiMesh).set_instance_transform(loc[1], xf * (entry["offsets"][i] as Transform3D))


## Tilts the tree around its base, away from `chopper`, by `angle` radians.
func _tilted(tree: Dictionary, chopper: Node3D, angle: float) -> Transform3D:
	var base: Transform3D = tree["xform"]
	var away := Vector3(base.origin.x - chopper.global_position.x, 0, base.origin.z - chopper.global_position.z)
	if away.length_squared() < 0.0001:
		away = Vector3.FORWARD
	var axis := Vector3.UP.cross(away.normalized()).normalized()
	return Transform3D(Basis(axis, angle) * base.basis, base.origin)


func _shake_tree(tree: Dictionary, chopper: Node3D) -> void:
	if tree["busy"]:
		return
	tree["busy"] = true
	var wobble := func(a: float) -> void:
		_set_tree_xform(tree, _tilted(tree, chopper, sin(a * PI * 5.0) * a * 0.07))
	var settle := func() -> void:
		tree["busy"] = false
		if not tree["felled"]:
			_set_tree_xform(tree, tree["xform"])
	var tw := create_tween()
	tw.tween_method(wobble, 1.0, 0.0, 0.4)
	tw.tween_callback(settle)
	tree["tween"] = tw


func _fell_tree(tree: Dictionary, chopper: Node3D) -> void:
	tree["felled"] = true
	tree["busy"] = true
	var old_tw = tree.get("tween")
	if old_tw is Tween and (old_tw as Tween).is_valid():
		(old_tw as Tween).kill()
	(tree["shape"] as CollisionShape3D).set_deferred("disabled", true)
	var base: Transform3D = tree["xform"]
	var away := Vector3(base.origin.x - chopper.global_position.x, 0, base.origin.z - chopper.global_position.z)
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	# Stump appears right away where the trunk stood.
	var stump := STUMP_SCENE.instantiate() as Node3D
	_root.add_child(stump)
	var ss: float = 2.0 * tree["scale"]
	stump.scale = Vector3(ss, ss, ss)
	stump.global_position = tree["pos"]
	stump.rotation.y = randf() * TAU
	tree["stump"] = stump
	# Topple away from the player, speeding up as it falls, then vanish and
	# leave the logs lying along where the trunk came down.
	var topple := func(a: float) -> void:
		_set_tree_xform(tree, _tilted(tree, chopper, a))
	var landed := func() -> void:
		_set_tree_xform(tree, Transform3D(Basis().scaled(Vector3.ZERO), base.origin))
		tree["busy"] = false
		_spawn_chips((tree["pos"] as Vector3) + away * 3.0 + Vector3(0, 0.4, 0))
		_drop_logs(tree, away)
	var tw := create_tween()
	tw.tween_method(topple, 0.0, PI * 0.47, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(landed)
	get_tree().create_timer(REGROW_TIME).timeout.connect(_regrow.bind(tree))


func _drop_logs(tree: Dictionary, away: Vector3) -> void:
	var origin: Vector3 = tree["pos"]
	var side := Vector3.UP.cross(away)
	for k in WOOD_PER_TREE:
		var along := 1.2 + k * 0.9 + randf_range(-0.2, 0.2)
		var target := origin + away * along + side * randf_range(-0.8, 0.8)
		target.y = height_at(target.x, target.z) + 0.12
		_spawn_log(origin + Vector3(0, 1.2, 0) + away * along * 0.5, target)


func _spawn_log(from: Vector3, to: Vector3) -> void:
	var area := Area3D.new()
	area.name = "WoodLog"
	area.add_to_group("wood_logs")
	area.collision_layer = 0          # never gets hit by attack sphere-casts
	area.collision_mask = 0xFFFFFFFF  # but notices whoever walks over it
	area.monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var cs := CollisionShape3D.new()
	cs.shape = shape
	area.add_child(cs)
	var mesh := LOG_SCENE.instantiate() as Node3D
	mesh.scale = Vector3(1.2, 1.2, 1.2)
	area.add_child(mesh)
	_root.add_child(area)
	area.global_position = from
	area.rotation.y = randf() * TAU
	var tw := area.create_tween()
	tw.tween_property(area, "global_position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	area.body_entered.connect(_try_collect_log.bind(area))
	var make_ready := func() -> void:
		if not is_instance_valid(area):
			return
		area.set_meta("ready", true)
		for b in area.get_overlapping_bodies():
			_try_collect_log(b, area)
	get_tree().create_timer(LOG_PICKUP_DELAY).timeout.connect(make_ready)


func _try_collect_log(body: Node, area: Area3D) -> void:
	if not is_instance_valid(area) or not area.get_meta("ready", false) or area.get_meta("taken", false):
		return
	if not (body.is_in_group("player") and body.has_method("add_item")):
		return
	area.set_meta("taken", true)
	body.add_item("wood")
	_spawn_pickup_vfx(area.global_position)
	# Chopping a tree is loud — alert nearby enemies to the pickup position
	if body.has_signal("made_noise"):
		body.made_noise.emit(area.global_position, 0.9)
	var tw := area.create_tween()
	tw.tween_property(area, "global_position", area.global_position + Vector3(0, 1.0, 0), 0.2)
	tw.parallel().tween_property(area, "scale", Vector3(0.05, 0.05, 0.05), 0.2)
	tw.tween_callback(area.queue_free)


func _spawn_pickup_vfx(at: Vector3) -> void:
	# Gold sparkle burst when the player picks up a wood log.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 22
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 65.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.8
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	# Gold sparkle quad
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	# Radial glow texture (same technique as sun motes)
	var glow := Gradient.new()
	glow.set_color(0, Color(1, 1, 1, 1))
	glow.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = glow
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	m.albedo_color = Color(1.0, 0.82, 0.18)
	q.material = m
	p.mesh = q
	# Fade from bright gold to transparent over lifetime
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.65, 0.1, 0.0))
	p.color_ramp = grad
	_root.add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _regrow(tree: Dictionary) -> void:
	# Don't grow a trunk up through the player - check again in a few seconds.
	for pl in get_tree().get_nodes_in_group("player"):
		var pp: Vector3 = (pl as Node3D).global_position
		var tp: Vector3 = tree["pos"]
		if Vector2(pp.x - tp.x, pp.z - tp.z).length() < 1.5:
			get_tree().create_timer(3.0).timeout.connect(_regrow.bind(tree))
			return
	if tree["stump"] and is_instance_valid(tree["stump"]):
		(tree["stump"] as Node3D).queue_free()
	tree["stump"] = null
	(tree["shape"] as CollisionShape3D).set_deferred("disabled", false)
	var base: Transform3D = tree["xform"]
	var grow := func(g: float) -> void:
		_set_tree_xform(tree, Transform3D(base.basis.scaled(Vector3(g, g, g)), base.origin))
	var grown := func() -> void:
		tree["hp"] = TREE_HITS
		tree["felled"] = false
	var tw := create_tween()
	tw.tween_method(grow, 0.05, 1.0, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(grown)


func _spawn_chips(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.05, 0.12)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.38, 0.2)
	box.material = m
	p.mesh = box
	_root.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
