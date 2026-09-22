extends Node
class_name AttackController

signal attack_landed(damage: int, position: Vector3)

@export var melee_damage: int = 15
@export var melee_range: float = 2.0
@export var melee_ocali_cost: int = 10
@export var attack_cooldown: float = 0.4

var _can_attack: bool = true
var _player: Player

@onready var _cooldown_timer: Timer = $CooldownTimer


func _ready() -> void:
	_cooldown_timer.wait_time = attack_cooldown
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_done)


func init(player: Player) -> void:
	_player = player


func try_melee_attack(camera: Camera3D) -> void:
	if not _can_attack:
		return
	if not _player.spend_ocali(melee_ocali_cost):
		return  # not enough Ocali

	_can_attack = false
	_cooldown_timer.start()

	var space_state := _player.get_world_3d().direct_space_state
	var center := camera.get_viewport().get_visible_rect().size / 2
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var end := origin + direction * melee_range

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [_player.get_rid()]
	var result := space_state.intersect_ray(query)

	if result:
		var hit_pos: Vector3 = result["position"]
		emit_signal("attack_landed", melee_damage, hit_pos)
		if result["collider"].has_method("take_damage"):
			result["collider"].take_damage(melee_damage)


func _on_cooldown_done() -> void:
	_can_attack = true
