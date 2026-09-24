extends Node2D

const MAP_W := 200
const MAP_H := 150
const MAP_PX_W := MAP_W * 16  # 3200
const MAP_PX_H := MAP_H * 16  # 2400

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

# God mode
const PLAY_ZOOM := Vector2(1.5, 1.5)
const GOD_ZOOM  := Vector2(0.25, 0.25)
var _god_mode := false

# Minimap
const MINIMAP_W := 240
const MINIMAP_H := 180
var _minimap_dot: ColorRect = null
var _minimap_offset := Vector2.ZERO

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
	_setup_minimap()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		_god_mode = !_god_mode
		var cam: Camera2D = $Player2D/Camera2D
		cam.zoom = GOD_ZOOM if _god_mode else PLAY_ZOOM

func _process(_delta: float) -> void:
	if _minimap_dot != null and is_instance_valid($Player2D):
		var p: Vector2 = $Player2D.position
		_minimap_dot.position = _minimap_offset + Vector2(
			(p.x / MAP_PX_W) * MINIMAP_W - 3.0,
			(p.y / MAP_PX_H) * MINIMAP_H - 3.0
		)

func _setup_minimap() -> void:
	# CanvasLayer sits on top of everything
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	# Dark border background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.size = Vector2(MINIMAP_W + 4, MINIMAP_H + 4)
	bg.position = UIPositions.MINIMAP
	ui.add_child(bg)

	# SubViewportContainer
	var container := SubViewportContainer.new()
	container.size = Vector2(MINIMAP_W, MINIMAP_H)
	container.position = bg.position + Vector2(2, 2)
	ui.add_child(container)
	_minimap_offset = container.position

	# SubViewport sharing this scene's World2D
	var vp := SubViewport.new()
	vp.size = Vector2i(MINIMAP_W, MINIMAP_H)
	vp.world_2d = get_world_2d()
	vp.disable_3d = true
	container.add_child(vp)

	# Camera inside the SubViewport, centered on the full map
	var cam := Camera2D.new()
	cam.position = Vector2(MAP_PX_W / 2.0, MAP_PX_H / 2.0)
	cam.zoom = Vector2(
		float(MINIMAP_W) / MAP_PX_W,
		float(MINIMAP_H) / MAP_PX_H
	)
	vp.add_child(cam)

	# Thin white frame around minimap
	var frame := ColorRect.new()
	frame.color = Color(1.0, 1.0, 1.0, 0.4)
	frame.size = Vector2(MINIMAP_W + 2, MINIMAP_H + 2)
	frame.position = bg.position + Vector2(1, 1)
	ui.add_child(frame)

	# Bring the container in front of the frame
	ui.move_child(container, ui.get_child_count() - 1)

	# Red player dot (drawn on top of the SubViewportContainer in the CanvasLayer)
	_minimap_dot = ColorRect.new()
	_minimap_dot.color = Color(1.0, 0.15, 0.15)
	_minimap_dot.size = Vector2(6, 6)
	ui.add_child(_minimap_dot)

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
