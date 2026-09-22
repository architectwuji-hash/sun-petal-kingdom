extends Node
class_name PowerHandler

@export var sunflower_burst_amount: int = 150
@export var sunflower_burst_cost: int = 75

var _player: Player
var _loadout: FlowerLoadout


func init(player: Player, loadout: FlowerLoadout) -> void:
	_player = player
	_loadout = loadout


func use_power() -> void:
	var flower: String = _loadout.get_active_flower()
	if flower == "":
		return
	match flower:
		"Sunflower":
			_use_sunflower()


func _use_sunflower() -> void:
	# Sunflower power 1: Burst regen — instant +150 Ocali for 75 Ocali cost
	# Can only use if you have enough Ocali to pay the cost
	if _player.ocali <= sunflower_burst_cost:
		return
	if not _player.spend_ocali(sunflower_burst_cost):
		return
	_player.restore_ocali(sunflower_burst_amount)
