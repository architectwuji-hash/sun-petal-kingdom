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
	# ── Column A ──
	"A1":"village",      "A2":"meadow",       "A3":"path",         "A4":"path",
	"A5":"path",         "A6":"dense_forest", "A7":"dense_forest", "A8":"dense_forest",
	"A9":"dense_forest", "A10":"river",       "A11":"river",       "A12":"swamp",
	# ── Column B ──
	"B1":"meadow",       "B2":"meadow",       "B3":"meadow",       "B4":"light_forest",
	"B5":"path",         "B6":"dense_forest", "B7":"sacred",       "B8":"dense_forest",
	"B9":"dense_forest", "B10":"river",       "B11":"river",       "B12":"river",
	# ── Column C ──
	"C1":"path",         "C2":"path",         "C3":"path",         "C4":"path",
	"C5":"path",         "C6":"dense_forest", "C7":"dense_forest", "C8":"dense_forest",
	"C9":"dense_forest", "C10":"river",       "C11":"river",       "C12":"river",
	# ── Column D ──
	"D1":"path",         "D2":"dense_forest", "D3":"dense_forest", "D4":"dense_forest",
	"D5":"dense_forest", "D6":"dense_forest", "D7":"dense_forest", "D8":"dense_forest",
	"D9":"dense_forest", "D10":"dense_forest","D11":"dense_forest","D12":"cave",
	# ── Column E ──
	"E1":"path",         "E2":"dense_forest", "E3":"dense_forest", "E4":"path",
	"E5":"path",         "E6":"path",         "E7":"path",         "E8":"path",
	"E9":"path",         "E10":"path",        "E11":"path",        "E12":"dense_forest",
	# ── Column F ──
	"F1":"path",         "F2":"dense_forest", "F3":"dense_forest", "F4":"path",
	"F5":"river",        "F6":"river",        "F7":"dense_forest", "F8":"cave",
	"F9":"dense_forest", "F10":"meadow",      "F11":"path",        "F12":"dense_forest",
	# ── Column G ──
	"G1":"path",         "G2":"dense_forest", "G3":"dense_forest", "G4":"path",
	"G5":"river",        "G6":"river",        "G7":"dense_forest", "G8":"dense_forest",
	"G9":"dense_forest", "G10":"meadow",      "G11":"path",        "G12":"dense_forest",
	# ── Column H ──
	"H1":"path",         "H2":"dense_forest", "H3":"dense_forest", "H4":"path",
	"H5":"beach",        "H6":"beach",        "H7":"path",         "H8":"path",
	"H9":"path",         "H10":"path",        "H11":"path",        "H12":"dense_forest",
	# ── Column I ──
	"I1":"path",         "I2":"river",        "I3":"river",        "I4":"path",
	"I5":"cliffs",       "I6":"cliffs",       "I7":"path",         "I8":"cliffs",
	"I9":"cliffs",       "I10":"cliffs",      "I11":"cliffs",      "I12":"cliffs",
	# ── Column J ──
	"J1":"path",         "J2":"path",         "J3":"river",        "J4":"path",
	"J5":"path",         "J6":"cliffs",       "J7":"path",         "J8":"cliffs",
	"J9":"path",         "J10":"path",        "J11":"path",        "J12":"path",
	# ── Column K ──
	"K1":"ruins",        "K2":"path",         "K3":"river",        "K4":"light_forest",
	"K5":"path",         "K6":"cliffs",       "K7":"path",         "K8":"cliffs",
	"K9":"path",         "K10":"river",       "K11":"river",       "K12":"path",
	# ── Column L ──
	"L1":"ruins",        "L2":"path",         "L3":"river",        "L4":"meadow",
	"L5":"path",         "L6":"cliffs",       "L7":"path",         "L8":"path",
	"L9":"path",         "L10":"river",       "L11":"river",       "L12":"path",
	# ── Column M ──
	"M1":"ruins",        "M2":"path",         "M3":"river",        "M4":"light_forest",
	"M5":"path",         "M6":"cliffs",       "M7":"cliffs",       "M8":"cliffs",
	"M9":"dense_forest", "M10":"dense_forest","M11":"dense_forest","M12":"path",
	# ── Column N ──
	"N1":"path",         "N2":"path",         "N3":"river",        "N4":"meadow",
	"N5":"path",         "N6":"path",         "N7":"path",         "N8":"path",
	"N9":"dense_forest", "N10":"dense_forest","N11":"light_forest","N12":"path",
	# ── Column O ──
	"O1":"path",         "O2":"river",        "O3":"river",        "O4":"light_forest",
	"O5":"meadow",       "O6":"light_forest", "O7":"meadow",       "O8":"path",
	"O9":"dense_forest", "O10":"light_forest","O11":"meadow",      "O12":"meadow",
	# ── Column P ──
	"P1":"path",         "P2":"path",         "P3":"path",         "P4":"path",
	"P5":"path",         "P6":"path",         "P7":"path",         "P8":"path",
	"P9":"dense_forest", "P10":"light_forest","P11":"meadow",      "P12":"village",
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
					var r := rng.randf()
					if r < 0.62:
						tilemap.set_cell(1, pos, SRC_ID, D_TREE_A if rng.randf() < 0.55 else D_TREE_B)
					elif r < 0.68:
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
