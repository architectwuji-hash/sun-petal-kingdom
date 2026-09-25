@tool
extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
#  Sun Petal Kingdom — World Generator
#  Zone grid:  16 cols (A–P, west→east) × 12 rows (1–12, north→south)
#  Zone size:  12 × 12 tiles each
#  Map total:  192 × 144 tiles  =  3072 × 2304 px  (at 16 px/tile)
# ═══════════════════════════════════════════════════════════════════════════════

const ZONE_COLS  := 16
const ZONE_ROWS  := 12
const ZONE_W     := 12     # tiles wide per zone
const ZONE_H     := 12     # tiles tall per zone
const MAP_W      := ZONE_COLS * ZONE_W    # 192 tiles
const MAP_H      := ZONE_ROWS * ZONE_H   # 144 tiles
const MAP_PX_W   := MAP_W * 16           # 3072 px
const MAP_PX_H   := MAP_H * 16           # 2304 px

const PLAY_ZOOM  := Vector2(1.5, 1.5)
const GOD_ZOOM   := Vector2(0.25, 0.25)
var _god_mode    := false

const MINIMAP_W  := 240
const MINIMAP_H  := 180
var _minimap_dot    : ColorRect = null
var _minimap_offset := Vector2.ZERO

@onready var tilemap: TileMap = $TileMap

# ── TILE ATLAS CONFIGURATION ────────────────────────────────────────────────
# Kenney Roguelike/RPG Pack — roguelikeSheet_transparent.png
# Sheet: 57 cols × 31 rows, 16×16 px tiles, 1px separation between tiles.
const SRC_ID := 0
const T_GRASS := Vector2i(5, 0)    # solid bright green grass terrain
const T_DIRT  := Vector2i(5, 5)    # solid brown dirt / packed earth / path
const T_WATER := Vector2i(0, 0)    # teal water (has collision)
const T_SAND  := Vector2i(14, 16)  # beige / sand terrain
const T_STONE := Vector2i(7, 0)    # grey stone wall / cliff (has collision)
const T_DARK  := Vector2i(20, 12)  # dark grey stone floor (cave / dungeon)
const T_MUD   := Vector2i(5, 5)    # swamp mud — fallback to dirt tile

# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func _ready() -> void:
	while tilemap.get_layers_count() < 2:
		tilemap.add_layer(-1)
	if Engine.is_editor_hint():
		return
	_paint_map()
	_setup_minimap()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.keycode == KEY_TAB \
			and event.pressed and not event.echo:
		_god_mode = !_god_mode
		var cam: Camera2D = $Player2D/Camera2D
		cam.zoom = GOD_ZOOM if _god_mode else PLAY_ZOOM

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _minimap_dot != null and is_instance_valid($Player2D):
		var p: Vector2 = $Player2D.position
		_minimap_dot.position = _minimap_offset + Vector2(
			(p.x / MAP_PX_W) * MINIMAP_W - 3.0,
			(p.y / MAP_PX_H) * MINIMAP_H - 3.0
		)

# ── MAP GENERATION ──────────────────────────────────────────────────────────

func _paint_map() -> void:
	tilemap.clear()
	for x: int in MAP_W:
		for y: int in MAP_H:
			tilemap.set_cell(0, Vector2i(x, y), SRC_ID, T_GRASS)

# ── MINIMAP ─────────────────────────────────────────────────────────────────

func _setup_minimap() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.size = Vector2(MINIMAP_W + 4, MINIMAP_H + 4)
	bg.position = UIPositions.MINIMAP
	ui.add_child(bg)

	var container := SubViewportContainer.new()
	container.size = Vector2(MINIMAP_W, MINIMAP_H)
	container.position = bg.position + Vector2(2, 2)
	ui.add_child(container)
	_minimap_offset = container.position

	var vp := SubViewport.new()
	vp.size = Vector2i(MINIMAP_W, MINIMAP_H)
	vp.world_2d = get_world_2d()
	vp.disable_3d = true
	container.add_child(vp)

	var cam := Camera2D.new()
	cam.position = Vector2(MAP_PX_W / 2.0, MAP_PX_H / 2.0)
	cam.zoom = Vector2(float(MINIMAP_W) / MAP_PX_W, float(MINIMAP_H) / MAP_PX_H)
	vp.add_child(cam)

	_minimap_dot = ColorRect.new()
	_minimap_dot.color = Color(1.0, 0.15, 0.15)
	_minimap_dot.size = Vector2(6, 6)
	ui.add_child(_minimap_dot)
