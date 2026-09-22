extends Node
class_name OcaliRegen

@export var regen_rate: float = 30.0        # Ocali restored per second
@export var regen_delay: float = 2.0        # seconds after last spend before regen starts

var _player: Player
var _time_since_spent: float = 999.0
var _regenning: bool = false
var _prev_ocali: int = 0


func init(player: Player) -> void:
	_player = player
	_prev_ocali = player.ocali
	_player.ocali_changed.connect(_on_ocali_changed)


func _process(delta: float) -> void:
	if _player == null:
		return
	_time_since_spent += delta
	if _time_since_spent >= regen_delay and _player.ocali < _player.max_ocali:
		var amount := regen_rate * delta
		_player.restore_ocali(int(amount))


func _on_ocali_changed(current: int, maximum: int) -> void:
	# Reset delay timer any time Ocali is spent (drops below max)
	if current < _prev_ocali:
		_time_since_spent = 0.0
	_prev_ocali = current
