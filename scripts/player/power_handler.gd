extends Node
class_name PowerHandler

@export var sunflower_burst_amount: int = 150
@export var sunflower_burst_cost: int = 75
@export var rose_thorn_cost: int = 50

const RoseThornScene := preload("res://scenes/player/RoseThorn.tscn")

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
		"Rose":
			_use_rose()


func _use_sunflower() -> void:
	if _player.ocali <= sunflower_burst_cost:
		return
	if not _player.spend_ocali(sunflower_burst_cost):
		return
	_player.restore_ocali(sunflower_burst_amount)


func _use_rose() -> void:
	if not _player.spend_ocali(rose_thorn_cost):
		return
	var thorn: RoseThorn = RoseThornScene.instantiate()
	var attack_origin: Node3D = _player.get_node("AttackOrigin")
	thorn.global_position = attack_origin.global_position - Vector3(0, 0.5, 0)
	thorn.direction = -_player.global_transform.basis.z
	_player.get_parent().add_child(thorn)
