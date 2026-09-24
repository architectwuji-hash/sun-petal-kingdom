extends Node2D

# Forest Zone - Starting area
# Mana Seed summer tileset: 256x256px, 16x16 tiles, 16 cols x 16 rows
# Source ID 0, atlas coords Vector2i(col, row)

const MAP_W := 30
const MAP_H := 20

# Tile atlas positions (col, row) in the summer tileset
const GRASS       := Vector2i(1, 0)   # olive green grass
const GRASS_ALT   := Vector2i(0, 1)   # slightly different grass
const DIRT        := Vector2i(4, 0)   # brown dirt/path
const TREE        := Vector2i(13, 1)  # deep green tree top
const FLOWER      := Vector2i(12, 0)  # bright green accent

# TileMap layer indices
const LAYER_GROUND  := 0
const LAYER_DETAILS := 1

@onready var tilemap: TileMap = $TileMap

func _ready() -> void:
	# Ensure we have 2 layers
	while tilemap.get_layers_count() < 2:
		tilemap.add_layer(-1)
	_paint_map()

func _paint_map() -> void:
	for x in range(MAP_W):
		for y in range(MAP_H):
			var is_border := (x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1)
			if is_border:
				tilemap.set_cell(LAYER_GROUND, Vector2i(x, y), 0, TREE)
			else:
				# Checkerboard of two grass variants for subtle texture
				var g := GRASS if (x + y) % 3 != 0 else GRASS_ALT
				tilemap.set_cell(LAYER_GROUND, Vector2i(x, y), 0, g)

	# Scatter detail tiles
	var detail_spots := [
		Vector2i(5, 5), Vector2i(10, 3), Vector2i(18, 7),
		Vector2i(22, 12), Vector2i(8, 14), Vector2i(15, 10),
		Vector2i(3, 9), Vector2i(25, 5), Vector2i(12, 16),
	]
	for pos in detail_spots:
		tilemap.set_cell(LAYER_DETAILS, pos, 0, FLOWER)
