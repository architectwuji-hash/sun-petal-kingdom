extends Node
class_name AttackController

signal attack_landed(damage: int, position: Vector3)

@export var melee_range: float = 3.0
@export var melee_ocali_cost: int = 10
@export var attack_cooldown: float = 0.4

var _can_attack: bool = true
var _player: Player
var _attack_origin: Node3D

@onready var _cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_cooldown_timer.wait_time = attack_cooldown
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_done)


func init(player: Player) -> void:
	_player = player
	_attack_origin = player.get_node("AttackOrigin")


func try_melee_attack(_camera: Camera3D) -> void:
	if not _can_attack:
		return
	if not _player.spend_ocali(melee_ocali_cost):
		return
	_can_attack = false
	_cooldown_timer.start()
	var damage: int = _player.level * 10
	var space_state := _player.get_world_3d().direct_space_state
	var origin := _attack_origin.global_position
	var direction := -_player.global_transform.basis.z
	var end := origin + direction * melee_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [_player.get_rid()]
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	if result:
		var collider = result["collider"]
		var hit_pos: Vector3 = result["position"]
		emit_signal("attack_landed", damage, hit_pos)
		if collider.has_method("take_damage"):
			collider.take_damage(damage)


func _on_cooldown_done() -> void:
	_can_attack = true
