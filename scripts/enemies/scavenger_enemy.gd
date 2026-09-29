## scavenger_enemy.gd — Day-only Wasteland Scavenger enemy
## Extends EnemyBase. Only active during the day — freezes at night.
## Moderate strength, intended to be encountered naturally while exploring.
extends "res://scripts/enemies/enemy_base.gd"

var _is_sleeping: bool = false  # True at night — completely frozen

func _ready() -> void:
	if enemy_name == "Enemy":
		enemy_name = "Scavenger"
	# Moderate stats — tough enough to matter but not overwhelming early on
	if hit_damage == 10:
		hit_damage = 12
	if move_speed == 3.0:
		move_speed = 2.5        # Slow, deliberate
	detection_range = 12.0      # Shorter sight — easier to avoid while building up
	attack_range    = 1.6
	tint_color = Color(0.72, 0.58, 0.35)  # dusty tan
	super._ready()
	_check_day_night()
	var dn := _get_day_night()
	if dn:
		if not dn.day_started.is_connected(_on_day_started):
			dn.day_started.connect(_on_day_started)
		if not dn.night_started.is_connected(_on_night_started):
			dn.night_started.connect(_on_night_started)

func _get_day_night() -> Node:
	return get_tree().get_first_node_in_group("day_night")

func _check_day_night() -> void:
	var dn := _get_day_night()
	if dn == null:
		return
	_is_sleeping = dn.is_night()

func _on_day_started() -> void:
	_is_sleeping = false
	# Pop back up
	scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_night_started() -> void:
	_is_sleeping = true
	# Crouch down and wait for dawn
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.85, 0.4, 0.85), 1.2)

func _physics_process(delta: float) -> void:
	if _is_sleeping:
		return
	super._physics_process(delta)

func _die() -> void:
	var dn := _get_day_night()
	if dn:
		if dn.day_started.is_connected(_on_day_started):
			dn.day_started.disconnect(_on_day_started)
		if dn.night_started.is_connected(_on_night_started):
			dn.night_started.disconnect(_on_night_started)
	super._die()
