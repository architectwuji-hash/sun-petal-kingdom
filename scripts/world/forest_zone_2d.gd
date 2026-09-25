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
# Adjust these Vector2i values to match YOUR tileset atlas coordinates.
# Layer 0 = ground tiles,  Layer 1 = decoration / overlay tiles.
# SRC_ID is the TileSetAtlasSource index (usually 0).

const SRC_ID := 0

# Ground layer (layer 0)  — verified from seasonal_sample_summer.png pixel analysis
const T_GRASS := Vector2i(0, 1)    # green grass
const T_DIRT  := Vector2i(1, 1)    # brown dirt / packed earth / path
const T_WATER := Vector2i(7, 12)   # bright blue water (has collision)
const T_SAND  := Vector2i(9, 4)    # light tan beach sand
const T_STONE := Vector2i(10, 5)   # reddish cliff wall (has collision)
const T_DARK  := Vector2i(2, 11)   # dark cave stone floor
const T_MUD   := Vector2i(7, 12)   # swamp mud — fallback to water tile

# Decoration layer (layer 1)  — verified from tileset pixel analysis
const D_TREE_A := Vector2i(13, 1)  # dark green tree  (primary)
const D_TREE_B := Vector2i(15, 1)  # dark green tree  (variant)
const D_TREE_C := Vector2i(12, 0)  # medium green tree (light forest)
const D_BUSH   := Vector2i(0, 8)   # bush / shrub
const D_FLOWER := Vector2i(1, 8)   # bright flower / sacred plant
const D_RUINS  := Vector2i(10, 5)  # ruin stones — fallback to cliff tile

# ── ZONE MAP ────────────────────────────────────────────────────────────────
# Designed in the Sun Petal Kingdom Zone Editor.
# West (A) → East (P),  North (1) → South (12).

const COL_LETTERS: Array = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P"]

const ZONE_MAP: Dictionary = {
	# Concentric island layout:
	#   Lake (A-B, N-P cols + row 12) → Beach ring → Dense Forest ring
	#   → Light Forest buffer → Meadow clearing → Village (H6)

	# ── Column A (lake) ──
	"A1":"river",  "A2":"river",  "A3":"river",  "A4":"river",
	"A5":"river",  "A6":"river",  "A7":"river",  "A8":"river",
	"A9":"river",  "A10":"river", "A11":"river", "A12":"river",
	# ── Column B (lake) ──
	"B1":"river",  "B2":"river",  "B3":"river",  "B4":"river",
	"B5":"river",  "B6":"river",  "B7":"river",  "B8":"river",
	"B9":"river",  "B10":"river", "B11":"river", "B12":"river",
	# ── Column C (beach shore) ──
	"C1":"beach",  "C2":"beach",  "C3":"beach",  "C4":"beach",
	"C5":"beach",  "C6":"beach",  "C7":"beach",  "C8":"beach",
	"C9":"beach",  "C10":"beach", "C11":"beach", "C12":"river",
	# ── Column D (beach top/bot, dense forest body) ──
	"D1":"beach",        "D2":"dense_forest",  "D3":"dense_forest",
	"D4":"dense_forest", "D5":"dense_forest",  "D6":"dense_forest",
	"D7":"dense_forest", "D8":"dense_forest",  "D9":"dense_forest",
	"D10":"dense_forest","D11":"beach",        "D12":"river",
	# ── Column E (beach top/bot, dense forest body) ──
	"E1":"beach",        "E2":"dense_forest",  "E3":"dense_forest",
	"E4":"dense_forest", "E5":"dense_forest",  "E6":"dense_forest",
	"E7":"dense_forest", "E8":"dense_forest",  "E9":"dense_forest",
	"E10":"dense_forest","E11":"beach",        "E12":"river",
	# ── Column F (beach top/bot, dense outer, light inner) ──
	"F1":"beach",        "F2":"dense_forest",  "F3":"dense_forest",
	"F4":"light_forest", "F5":"light_forest",  "F6":"light_forest",
	"F7":"light_forest", "F8":"light_forest",  "F9":"dense_forest",
	"F10":"dense_forest","F11":"beach",        "F12":"river",
	# ── Column G (beach top/bot, dense outer, light/meadow inner) ──
	"G1":"beach",        "G2":"dense_forest",  "G3":"dense_forest",
	"G4":"light_forest", "G5":"meadow",        "G6":"meadow",
	"G7":"meadow",       "G8":"light_forest",  "G9":"dense_forest",
	"G10":"dense_forest","G11":"beach",        "G12":"river",
	# ── Column H (beach top/bot, dense outer, light, meadow, VILLAGE center) ──
	"H1":"beach",        "H2":"dense_forest",  "H3":"dense_forest",
	"H4":"light_forest", "H5":"meadow",        "H6":"village",
	"H7":"meadow",       "H8":"light_forest",  "H9":"dense_forest",
	"H10":"dense_forest","H11":"beach",        "H12":"river",
	# ── Column I (beach top/bot, dense outer, light/meadow inner) ──
	"I1":"beach",        "I2":"dense_forest",  "I3":"dense_forest",
	"I4":"light_forest", "I5":"meadow",        "I6":"meadow",
	"I7":"meadow",       "I8":"light_forest",  "I9":"dense_forest",
	"I10":"dense_forest","I11":"beach",        "I12":"river",
	# ── Column J (beach top/bot, dense outer, light inner) ──
	"J1":"beach",        "J2":"dense_forest",  "J3":"dense_forest",
	"J4":"light_forest", "J5":"light_forest",  "J6":"light_forest",
	"J7":"light_forest", "J8":"light_forest",  "J9":"dense_forest",
	"J10":"dense_forest","J11":"beach",        "J12":"river",
	# ── Column K (beach top/bot, dense forest body) ──
	"K1":"beach",        "K2":"dense_forest",  "K3":"dense_forest",
	"K4":"dense_forest", "K5":"dense_forest",  "K6":"dense_forest",
	"K7":"dense_forest", "K8":"dense_forest",  "K9":"dense_forest",
	"K10":"dense_forest","K11":"beach",        "K12":"river",
	# ── Column L (beach top/bot, dense forest body) ──
	"L1":"beach",        "L2":"dense_forest",  "L3":"dense_forest",
	"L4":"dense_forest", "L5":"dense_forest",  "L6":"dense_forest",
	"L7":"dense_forest", "L8":"dense_forest",  "L9":"dense_forest",
	"L10":"dense_forest","L11":"beach",        "L12":"river",
	# ── Column M (beach shore) ──
	"M1":"beach",  "M2":"beach",  "M3":"beach",  "M4":"beach",
	"M5":"beach",  "M6":"beach",  "M7":"beach",  "M8":"beach",
	"M9":"beach",  "M10":"beach", "M11":"beach", "M12":"river",
	# ── Column N (lake) ──
	"N1":"river",  "N2":"river",  "N3":"river",  "N4":"river",
	"N5":"river",  "N6":"river",  "N7":"river",  "N8":"river",
	"N9":"river",  "N10":"river", "N11":"river", "N12":"river",
	# ── Column O (lake) ──
	"O1":"river",  "O2":"river",  "O3":"river",  "O4":"river",
	"O5":"river",  "O6":"river",  "O7":"river",  "O8":"river",
	"O9":"river",  "O10":"river", "O11":"river", "O12":"river",
	# ── Column P (lake) ──
	"P1":"river",  "P2":"river",  "P3":"river",  "P4":"river",
	"P5":"river",  "P6":"river",  "P7":"river",  "P8":"river",
	"P9":"river",  "P10":"river", "P11":"river", "P12":"river",
}

# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func _ready() -> void:
	while tilemap.get_layers_count() < 2:
		tilemap.add_layer(-1)
	if Engine.is_editor_hint():
		return   # don't auto-paint in editor — paint manually via TileMap tool
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
	for col_idx: int in ZONE_COLS:
		for row_idx: int in ZONE_ROWS:
			var key: String = COL_LETTERS[col_idx] + str(row_idx + 1)
			var terrain: String = ZONE_MAP.get(key, "meadow")
			var origin := Vector2i(col_idx * ZONE_W, row_idx * ZONE_H)
			_paint_zone(origin, terrain, col_idx * 997 + row_idx * 31)

func _paint_zone(origin: Vector2i, terrain: String, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val  # deterministic — same map every load

	for dx: int in ZONE_W:
		for dy: int in ZONE_H:
			var pos := origin + Vector2i(dx, dy)
			tilemap.erase_cell(1, pos)  # clear decoration layer first

			match terrain:

				"dense_forest":
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)
					# Cluster trees using two overlapping noise bands
					var cx := float(dx) / ZONE_W
					var cy := float(dy) / ZONE_H
					var band := sin(cx * 3.14159 * rng.randf_range(1.5, 3.5)) * cos(cy * 3.14159 * rng.randf_range(1.5, 3.5))
					var density := 0.72 + band * 0.18
					var r := rng.randf()
					if r < density:
						tilemap.set_cell(1, pos, SRC_ID, D_TREE_A if rng.randf() < 0.55 else D_TREE_B)
					elif r < density + 0.06:
						tilemap.set_cell(1, pos, SRC_ID, D_BUSH)

				"light_forest":
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)
					var r := rng.randf()
					if r < 0.22:
						tilemap.set_cell(1, pos, SRC_ID, D_TREE_C)
					elif r < 0.30:
						tilemap.set_cell(1, pos, SRC_ID, D_BUSH)

				"meadow":
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)
					if rng.randf() < 0.07:
						tilemap.set_cell(1, pos, SRC_ID, D_FLOWER)

				"sacred":
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)
					var r := rng.randf()
					if r < 0.28:
						tilemap.set_cell(1, pos, SRC_ID, D_FLOWER)
					elif r < 0.38:
						tilemap.set_cell(1, pos, SRC_ID, D_TREE_C)

				"river":
					tilemap.set_cell(0, pos, SRC_ID, T_WATER)

				"swamp":
					tilemap.set_cell(0, pos, SRC_ID, T_MUD)
					if rng.randf() < 0.18:
						tilemap.set_cell(1, pos, SRC_ID, D_BUSH)

				"beach":
					tilemap.set_cell(0, pos, SRC_ID, T_SAND)

				"cliffs":
					tilemap.set_cell(0, pos, SRC_ID, T_STONE)

				"path":
					tilemap.set_cell(0, pos, SRC_ID, T_DIRT)

				"village":
					tilemap.set_cell(0, pos, SRC_ID, T_DIRT)
					# Village tiles — dirt base; buildings placed as scenes separately
					if rng.randf() < 0.06:
						tilemap.set_cell(1, pos, SRC_ID, D_FLOWER)

				"ruins":
					tilemap.set_cell(0, pos, SRC_ID, T_STONE)
					if rng.randf() < 0.38:
						tilemap.set_cell(1, pos, SRC_ID, D_RUINS)

				"cave":
					tilemap.set_cell(0, pos, SRC_ID, T_DARK)

				"landmark":
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)
					if rng.randf() < 0.12:
						tilemap.set_cell(1, pos, SRC_ID, D_FLOWER)

				_:  # fallback — treat as grass
					tilemap.set_cell(0, pos, SRC_ID, T_GRASS)

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
