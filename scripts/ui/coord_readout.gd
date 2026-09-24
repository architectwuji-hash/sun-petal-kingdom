# CoordReadout — shows live mouse position in screen pixels.
# Use this to find the exact coordinates for any UI element you want placed.
# Toggle with F1. Always off in release builds.
extends CanvasLayer

var _label: Label

func _ready() -> void:
	layer = 127  # always on top of everything

	# Semi-transparent dark pill background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.size = Vector2(180, 28)
	bg.position = Vector2(8, 8)
	add_child(bg)

	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))  # green readout
	_label.text = "mouse: (0, 0)"
	add_child(_label)

func _process(_delta: float) -> void:
	var m := get_viewport().get_mouse_position()
	_label.text = "mouse: (%d, %d)" % [int(m.x), int(m.y)]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.echo:
		visible = !visible
