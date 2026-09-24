extends Node2D

# Forest Zone - Starting area
# Godot 4.2: TileMap with layer indices (0=ground, 1=details, 2=foreground)
# TileSet must be assigned in the editor after importing the tileset PNG

const MAP_WIDTH: int = 30
const MAP_HEIGHT: int = 20

@onready var tilemap: TileMap = $TileMap

func _ready() -> void:
	# TileSet must be assigned in editor — skip painting if not set yet
	if tilemap.tile_set == null:
		print("ForestZone2D: Assign a TileSet to TileMap in the editor to see the map.")
		return
	_paint_initial_map()

func _paint_initial_map() -> void:
	# Layer 0 = ground, Layer 1 = details, Layer 2 = foreground
	# Ensure the TileMap has at least 3 layers
	while tilemap.get_layers_count() < 3:
		tilemap.add_layer(-1)

	# Tile atlas coordinates — adjust to match your tileset
	var GRASS  := Vector2i(0, 0)   # Top-left grass tile
	var BORDER := Vector2i(2, 0)   # A cliff/wall tile

	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var is_border := (x == 0 or y == 0 or x == MAP_WIDTH - 1 or y == MAP_HEIGHT - 1)
			if is_border:
				tilemap.set_cell(0, Vector2i(x, y), 0, BORDER)
			else:
				tilemap.set_cell(0, Vector2i(x, y), 0, GRASS)

	# Scatter a few decorative tiles on detail layer
	var details := [
		Vector2i(5, 6), Vector2i(12, 4), Vector2i(18, 8),
		Vector2i(22, 14), Vector2i(8, 15), Vector2i(14, 12),
	]
	var FLOWER := Vector2i(4, 3)
	for pos in details:
		tilemap.set_cell(1, pos, 0, FLOWER)
