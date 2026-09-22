extends CharacterBody3D
class_name Player

signal ocali_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.003
@export var max_health: int = 100
@export var max_ocali: int = 750

const GRAVITY: float = 20.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera
@onready var attack_controller: AttackController = $AttackController

var health: int = max_health
var ocali: int = max_ocali
var _camera_pitch: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	attack_controller.init(self)


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


func take_damage(amount: int) -> void:
	health = clampi(health - amount, 0, max_health)
	emit_signal("health_changed", health, max_health)


func spend_ocali(amount: int) -> bool:
	if ocali < amount:
		return false
	ocali -= amount
	emit_signal("ocali_changed", ocali, max_ocali)
	return true


func restore_ocali(amount: int) -> void:
	ocali = clampi(ocali + amount, 0, max_ocali)
	emit_signal("ocali_changed", ocali, max_ocali)
