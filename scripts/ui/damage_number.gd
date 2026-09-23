extends Label3D
class_name DamageNumber

var _lifetime: float = 0.0
const MAX_LIFETIME: float = 1.1
const RISE_SPEED: float = 1.8


func setup(amount: int) -> void:
	text = str(amount)
	font_size = 28
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	modulate = Color(1.0, 0.95, 0.2, 1.0)
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	outline_size = 8


func _process(delta: float) -> void:
	_lifetime += delta
	global_position.y += RISE_SPEED * delta
	modulate.a = 1.0 - (_lifetime / MAX_LIFETIME)
	if _lifetime >= MAX_LIFETIME:
		queue_free()
