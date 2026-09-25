extends Node3D

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation.y = sin(_t * 0.8) * 0.6
