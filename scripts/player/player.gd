extends CharacterBody3D
class_name Player

signal ocali_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal level_changed(new_level: int, xp: int, xp_required: int)
signal died

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.003
@export var max_ocali: int = 750
@export var respawn_delay: float = 3.0

const GRAVITY: float = 20.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera
@onready var attack_controller: AttackController = $AttackController
@onready var ocali_regen: OcaliRegen = $OcaliRegen
@onready var flower_loadout: FlowerLoadout = $FlowerLoadout
@onready var power_handler: PowerHandler = $PowerHandler

var level: int = 1
var xp: int = 0
var max_health: int = 100
var health: int = 100
var ocali: int = 750
var _camera_pitch: float = 0.0
var _is_dead: bool = false


func _get_xp_required() -> int:
	return level * level * 5


func _get_max_health_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 50


func _ready() -> void:
	add_to_group("player")
	max_health = _get_max_health_for_level(level)
	health = max_health
	ocali = max_ocali
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	attack_controller.init(self)
	ocali_regen.init(self)
	power_handler.init(self, flower_loadout)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.4)
		camera_pivot.rotation.x = _camera_pitch
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("melee_attack"):
		attack_controller.try_melee_attack(camera)
	if event.is_action_pressed("use_power"):
		power_handler.use_power()
	if event.is_action_pressed("slot_1"):
		flower_loadout.switch_slot(0)
	if event.is_action_pressed("slot_2"):
		flower_loadout.switch_slot(1)
	if event.is_action_pressed("slot_3"):
		flower_loadout.switch_slot(2)
	if event.is_action_pressed("slot_4"):
		flower_loadout.switch_slot(3)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()


func add_xp(amount: int) -> void:
	xp += amount
	var required: int = _get_xp_required()
	while xp >= required:
		xp -= required
		level += 1
		max_health = _get_max_health_for_level(level)
		health = max_health
		ocali = max_ocali
		emit_signal("health_changed", health, max_health)
		emit_signal("ocali_changed", ocali, max_ocali)
		required = _get_xp_required()
	emit_signal("level_changed", level, xp, required)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	health = clampi(health - amount, 0, max_health)
	emit_signal("health_changed", health, max_health)
	if health <= 0:
		_die()


func spend_ocali(amount: int) -> bool:
	if ocali < amount:
		return false
	ocali -= amount
	emit_signal("ocali_changed", ocali, max_ocali)
	return true


func restore_ocali(amount: int) -> void:
	ocali = clampi(ocali + amount, 0, max_ocali)
	emit_signal("ocali_changed", ocali, max_ocali)


func _die() -> void:
	_is_dead = true
	emit_signal("died")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	health = max_health
	ocali = max_ocali
	_is_dead = false
	global_position = Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	emit_signal("health_changed", health, max_health)
	emit_signal("ocali_changed", ocali, max_ocali)
	emit_signal("level_changed", level, xp, _get_xp_required())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
