extends CharacterBody3D

signal health_changed(new_val: int)

const SPEED: float = 12.0
const GRAVITY: float = 20.0
const CAM_LERP: float = 0.12
const CAM_HEIGHT: float = 5.0
const CAM_DISTANCE: float = 8.0
const ATTACK_COOLDOWN: float = 0.6

@onready var _anim: AnimationPlayer = $CharacterModel/AnimationPlayer
@onready var _attack_hitbox: Area3D = $AttackHitbox

var _camera: Camera3D
var health: int = 100
var _attacking: bool = false
var _attack_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_camera = get_parent().get_node("Camera3D")
	_attack_hitbox.monitoring = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_changed.emit(health)
	if _anim.has_animation("idle"):
		_anim.play("idle")


func set_health(value: int) -> void:
	var clamped: int = clampi(value, 0, 100)
	if health == clamped:
		return
	health = clamped
	health_changed.emit(health)


func _do_attack() -> void:
	_attacking = true
	_attack_timer = ATTACK_COOLDOWN
	_attack_hitbox.monitoring = true
	await get_tree().create_timer(0.15).timeout
	_attack_hitbox.monitoring = false
	_attacking = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * 0.003
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(_delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * _delta

	if _attack_timer > 0.0:
		_attack_timer -= _delta
	if Input.is_action_just_pressed("ui_accept") and _attack_timer <= 0.0 and not _attacking:
		_do_attack()

	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var direction: Vector3 = forward * -input_dir.y + right * input_dir.x
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if direction.length() > 0.1:
			var target_angle: float = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 0.15)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()

	global_position.x = clamp(global_position.x, -195.0, 195.0)
	global_position.z = clamp(global_position.z, -195.0, 195.0)

	_update_locomotion_anim()


func _update_locomotion_anim() -> void:
	if _anim == null:
		return
	if velocity.length() > 0.5 and _anim.has_animation("walk"):
		if _anim.current_animation != "walk":
			_anim.play("walk")
	elif _anim.has_animation("idle"):
		if _anim.current_animation != "idle":
			_anim.play("idle")


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var behind: Vector3 = -global_transform.basis.z
	var cam_target: Vector3 = global_position + Vector3(0.0, CAM_HEIGHT, 0.0) + behind * -CAM_DISTANCE
	_camera.global_position = _camera.global_position.lerp(cam_target, CAM_LERP)
	_camera.look_at(global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
