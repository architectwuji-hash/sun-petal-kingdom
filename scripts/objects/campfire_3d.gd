extends Node3D
## Campfire — flickers the OmniLight3D child called "Glow" to simulate
## a living fire. No external assets needed; everything is built from
## Godot primitives in Campfire3D.tscn.

@export var base_energy: float = 2.5
@export var energy_variance: float = 0.7
@export var flicker_speed: float = 4.0

var _light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	_light = get_node_or_null("Glow") as OmniLight3D


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	# Three overlapping sine waves give an organic, non-repeating flicker.
	var f: float = (sin(_t * flicker_speed * 1.1) * 0.5
				  + sin(_t * flicker_speed * 2.9) * 0.3
				  + sin(_t * flicker_speed * 0.6) * 0.2)
	_light.light_energy = base_energy + f * energy_variance
	# Shift between warm yellow and deep orange as the flicker varies.
	var warm: float = clamp(0.5 + f * 0.4, 0.1, 0.9)
	_light.light_color = Color(1.0, 0.45 + warm * 0.45, warm * 0.12)
