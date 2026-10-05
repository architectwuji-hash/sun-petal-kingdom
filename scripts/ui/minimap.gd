extends Control
class_name MiniMap

## ── Landmark definitions ─────────────────────────────────────────────────────
## Add / move entries here whenever new areas are created.
## `pos` is the world-space Vector3 centre of the location (Y ignored).
const LANDMARKS: Array = [
	{"label": "Home",        "pos": Vector3(-7.0,   0.0,  -8.0), "color": Color(0.40, 0.80, 1.00)},
	{"label": "Suji Village","pos": Vector3(195.0,  0.0,  95.0), "color": Color(1.00, 0.55, 0.15)},
]

## ── Visual constants ─────────────────────────────────────────────────────────
const RADIUS:        float = 70.0    ## minimap half-size in pixels (140×140)
const MAP_SCALE:     float = 0.35    ## pixels per world unit  (140 px ≈ 400 wu)
const DOT_PLAYER:    float = 4.5
const DOT_LANDMARK:  float = 5.0
const LABEL_OFFSET:  Vector2 = Vector2(8.0, 3.5)
const LABEL_SIZE:    int   = 10

const COL_BG:        Color = Color(0.04, 0.07, 0.04, 0.82)
const COL_RING:      Color = Color(0.25, 0.55, 0.25, 1.00)
const COL_GRID:      Color = Color(1.00, 1.00, 1.00, 0.06)
const COL_PLAYER:    Color = Color(1.00, 1.00, 1.00, 1.00)
const COL_LABEL:     Color = Color(1.00, 1.00, 1.00, 0.92)
const COL_ARROW:     Color = Color(1.00, 0.95, 0.25, 1.00)   ## edge indicator

## ── State ─────────────────────────────────────────────────────────────────────
var _player: CharacterBody3D = null

# ─────────────────────────────────────────────────────────────────────────────
func set_player(player: CharacterBody3D) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player != null:
		queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var center := Vector2(RADIUS, RADIUS)

	# ── Background circle ─────────────────────────────────────────────────
	draw_circle(center, RADIUS, COL_BG)

	# ── Subtle grid cross ─────────────────────────────────────────────────
	draw_line(Vector2(center.x, 2.0), Vector2(center.x, RADIUS * 2.0 - 2.0), COL_GRID, 1.0)
	draw_line(Vector2(2.0, center.y), Vector2(RADIUS * 2.0 - 2.0, center.y), COL_GRID, 1.0)

	if _player != null:
		_draw_landmarks(center)

	# ── Player dot (always centre) ────────────────────────────────────────
	draw_circle(center, DOT_PLAYER, COL_PLAYER)

	# ── Border ring (drawn last so it covers clipped dots) ────────────────
	draw_arc(center, RADIUS - 1.5, 0.0, TAU, 64, COL_RING, 2.5)

	# ── "N" north label ───────────────────────────────────────────────────
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(RADIUS - 4.0, 12.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.6, 0.9, 0.6, 0.85))


# ─────────────────────────────────────────────────────────────────────────────
func _draw_landmarks(center: Vector2) -> void:
	var ppos: Vector3 = _player.global_position
	var font:  Font   = ThemeDB.fallback_font

	for lm: Dictionary in LANDMARKS:
		var wpos:  Vector3 = lm["pos"] as Vector3
		var col:   Color   = lm["color"] as Color
		var label: String  = lm["label"] as String

		# ── World → minimap pixel offset ─────────────────────────────────
		var dx:  float = (wpos.x - ppos.x) * MAP_SCALE
		var dz:  float = (wpos.z - ppos.z) * MAP_SCALE
		var mp := center + Vector2(dx, dz)

		var delta:  Vector2 = mp - center
		var inside: bool    = delta.length() < RADIUS - DOT_LANDMARK - 2.0

		if inside:
			# ── Draw filled dot + label ───────────────────────────────────
			draw_circle(mp, DOT_LANDMARK, col)
			draw_arc(mp, DOT_LANDMARK + 1.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.5)
			draw_string(font, mp + LABEL_OFFSET, label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, COL_LABEL)
		else:
			# ── Edge arrow pointing toward off-screen landmark ────────────
			var edge_pt: Vector2 = center + delta.normalized() * (RADIUS - 10.0)
			_draw_arrow(edge_pt, delta.normalized(), col, label, font)


# ─────────────────────────────────────────────────────────────────────────────
func _draw_arrow(tip: Vector2, dir: Vector2, col: Color,
		label: String, font: Font) -> void:
	## Tiny triangle pointing toward the off-screen landmark.
	var sz:    float   = 6.0
	var perp:  Vector2 = Vector2(-dir.y, dir.x)
	var p1: Vector2    = tip + dir * sz
	var p2: Vector2    = tip - perp * sz * 0.5
	var p3: Vector2    = tip + perp * sz * 0.5
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([col, col, col]))

	# Distance label near the arrow
	var dist: float = (_player.global_position -
			(LANDMARKS.filter(func(lm: Dictionary) -> bool:
				return lm["label"] == label)[0]["pos"] as Vector3)).length()
	var dist_str: String = label + "  " + str(int(dist)) + "m"
	draw_string(font, tip + Vector2(8.0, 4.0), dist_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
