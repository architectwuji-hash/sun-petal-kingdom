## slime_enemy.gd — Night-only Slime enemy
## Extends EnemyBase; only active between sunset and sunrise.
## Despawns at dawn by shrinking and freeing itself.
extends "res://scripts/enemies/enemy_base.gd"

@export var slime_jump_height: float  = 3.5
@export var slime_jump_cooldown: float = 1.8

var _jump_timer: float = 0.0
var _is_sleeping: bool = false

func _ready() -> void:
	if enemy_name == "Enemy":
		enemy_name = "Slime"
	if hit_damage == 10:
		hit_damage = 8
	if move_speed == 3.0:
		move_speed = 2.8
	tint_color = Color(0.15, 0.85, 0.35)
	super._ready()
	_check_day_night()
	var dn = _get_day_night()
	if dn:
		if not dn.day_started.is_connected(_on_day_started):
			dn.day_started.connect(_on_day_started)
		if not dn.night_started.is_connected(_on_night_started):
			dn.night_started.connect(_on_night_started)

func _get_day_night() -> Node:
	## DayNightCycle is a child of the root scene (added by forest_zone_3d.gd).
	return get_tree().get_first_node_in_group("day_night")

func _check_day_night() -> void:
	var dn := _get_day_night()
	if dn == null:
		return
	_is_sleeping = not dn.is_night()

func _on_day_started() -> void:
	_is_sleeping = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.0, 0.0, 0.0), 2.5)
	tw.tween_callback(queue_free)

func _on_night_started() -> void:
	_is_sleeping = false
	scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	if _is_sleeping:
		return
	super._physics_process(delta)
	if (_state == State.CHASE or _state == State.ATTACK) and is_on_floor():
		_jump_timer -= delta
		if _jump_timer <= 0.0:
			_jump_timer = slime_jump_cooldown
			velocity.y = slime_jump_height * 4.0

func _die() -> void:
	var dn := _get_day_night()
	if dn:
		if dn.day_started.is_connected(_on_day_started):
			dn.day_started.disconnect(_on_day_started)
		if dn.night_started.is_connected(_on_night_started):
			dn.night_started.disconnect(_on_night_started)
	super._die()
