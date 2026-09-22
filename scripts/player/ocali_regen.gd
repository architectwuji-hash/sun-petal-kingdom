extends Node
class_name OcaliRegen

@export var regen_rate: float = 30.0
@export var regen_delay: float = 2.0

var _player: Player
var _time_since_spent: float = 999.0
var _prev_ocali: int = -1
var _regen_accumulator: float = 0.0


func init(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	if _player == null:
		return
	var current_ocali: int = _player.ocali
	if _prev_ocali >= 0 and current_ocali < _prev_ocali:
		_time_since_spent = 0.0
		_regen_accumulator = 0.0
	_prev_ocali = current_ocali
	_time_since_spent += delta
	if _time_since_spent >= regen_delay and _player.ocali < _player.max_ocali:
		_regen_accumulator += regen_rate * delta
		if _regen_accumulator >= 1.0:
			var amount: int = int(_regen_accumulator)
			_regen_accumulator -= float(amount)
			_player.restore_ocali(amount)
