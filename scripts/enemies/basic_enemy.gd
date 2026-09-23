extends CharacterBody3D
class_name BasicEnemy

signal died

@export var max_health: int = 60
@export var move_speed: float = 2.5
@export var attack_range: float = 1.8
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2
@export var detection_range: float = 12.0

const GRAVITY: float = 20.0
const DamageNumberScene := preload("res://scenes/ui/DamageNumber.tscn")

var health: int = max_health
var _player: Player = null
var _can_attack: bool = true

@onready var health_label: Label3D = $HealthLabel
@onready var attack_timer: Timer = $AttackTimer
@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	health = max_health
	_update_label()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_ready)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _player == null:
		move_and_slide()
		return
	var distance: float = global_position.distance_to(_player.global_position)
	if distance <= detection_range:
		var direction: Vector3 = (_player.global_position - global_position).normalized()
		direction.y = 0.0
		look_at(global_position + direction, Vector3.UP)
		if distance > attack_range:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _can_attack:
				_do_attack()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _do_attack() -> void:
	_can_attack = false
	attack_timer.start()
	_player.take_damage(attack_damage)


func _on_attack_ready() -> void:
	_can_attack = true


func take_damage(amount: int) -> void:
	health -= amount
	_update_label()
	_spawn_damage_number(amount)
	if health <= 0:
		die()


func _spawn_damage_number(amount: int) -> void:
	var num: DamageNumber = DamageNumberScene.instantiate()
	get_parent().add_child(num)
	num.global_position = global_position + Vector3(
		randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3)
	)
	num.setup(amount)


func die() -> void:
	emit_signal("died")
	queue_free()


func _update_label() -> void:
	if health_label:
		health_label.text = str(health) + " / " + str(max_health)
