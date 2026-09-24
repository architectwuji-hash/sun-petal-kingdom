extends Node2D

const MAP_W := 200
const MAP_H := 150

# --- Grass variants (light to medium) ---
const G00 := Vector2i(1, 0)   # bright grass
const G01 := Vector2i(2, 0)   # grass darker patch
const G02 := Vector2i(3, 0)   # grass pale
const G10 := Vector2i(0, 1)   # grass fresh
const G11 := Vector2i(1, 1)   # grass medium
const G12 := Vector2i(2, 1)   # grass-dirt blend light
const G20 := Vector2i(0, 2)   # grass cool tone
const G21 := Vector2i(1, 2)   # grass
const G22 := Vector2i(2, 2)   # grass-dirt blend dark

# --- Dirt/soil ---
const D0  := Vector2i(4, 0)   # dark dirt
const D1  := Vector2i(4, 1)   # mid dirt
const D2  := Vector2i(4, 2)   # light dirt
const DM  := Vector2i(3, 1)   # dirt-grass mix

# --- Border ---
const TREE := Vector2i(13, 1)

const LAYER_GROUND := 0

@onready var tilemap: TileMap = $TileMap

# Primary grass pool  (high probability)
const GRASS_POOL := [
	Vector2i(1,0), Vector2i(1,0), Vector2i(1,0),   # bias toward base grass
	Vector2i(0,1), Vector2i(1,1),
	Vector2i(0,2), Vector2i(1,2),
	Vector2i(2,0), Vector2i(2,1),
]

# Occasional accent tiles (low probability dirt patches / pale grass)
const ACCENT_POOL := [
	Vector2i(3,0), Vector2i(3,1),
	Vector2i(4,1), Vector2i(4,2),
	Vector2i(2,2),
]

func _ready() -> void:
	while tilemap.get_layers_count() < 2:
		tilemap.add_layer(-1)
	_paint_map()

func _paint_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # fixed seed = same map every run

	for x in range(MAP_W):
		for y in range(MAP_H):
			var is_border := (x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1)
			if is_border:
				tilemap.set_cell(LAYER_GROUND, Vector2i(x, y), 0, TREE)
				continue

			# Every cell gets a terrain tile
			var roll := rng.randf()
			var tile: Vector2i
			if roll < 0.80:
				# 80 % — primary grass variants
				tile = GRASS_POOL[rng.randi() % GRASS_POOL.size()]
			else:
				# 20 % — accent / dirt patch
				tile = ACCENT_POOL[rng.randi() % ACCENT_POOL.size()]

			tilemap.set_cell(LAYER_GROUND, Vector2i(x, y), 0, tile)
