extends CharacterBody3D

signal health_changed(new_val: int)
signal player_died

const SPEED: float = 5.0
const SPRINT_SPEED: float = 9.0
const GRAVITY: float = 20.0
const CAM_LERP: float = 0.12
const CAM_OFFSET: Vector3 = Vector3(0.0, 8.0, 12.0)
const ATTACK_COOLDOWN: float = 0.6

@onready var _anim: AnimationPlayer = $CharacterModel/AnimationPlayer
@onready var _attack_hitbox: Area3D = $AttackHitbox

var _camera: Camera3D
var health: int = 100
var _attacking: bool = false
var _attack_timer: float = 0.0
var _cam_shake: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_camera = get_parent().get_node("Camera3D")
	_attack_hitbox.monitoring = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_changed.emit(health)
	if _anim.has_animation("idle"):
		_anim.play("idle")


func set_health(val: int) -> void:
	var prev: int = health
	health = clampi(val, 0, 100)
	if health == prev:
		return
	health_changed.emit(health)
	if health < prev:
		take_hit()
	if health <= 0:
		player_died.emit()


func take_hit() -> void:
	_cam_shake = 1.0


func _do_attack() -> void:
	_attacking = true
	_attack_timer = ATTACK_COOLDOWN
	_attack_hitbox.monitoring = true
	await get_tree().create_timer(0.15).timeout
	_attack_hitbox.monitoring = false
	_attacking = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0015


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		if _attack_timer <= 0.0 and not _attacking:
			_do_attack()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _attack_timer <= 0.0 and not _attacking:
		_do_attack()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(_delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * _delta

	if _attack_timer > 0.0:
		_attack_timer -= _delta

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y = -1.0
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y = 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x = 1.0
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var direction: Vector3 = forward * -input_dir.y + right * input_dir.x
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		var sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
		var move_speed: float = SPRINT_SPEED if sprinting else SPEED
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
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
	var moving: bool = velocity.length() > 0.5
	var sprinting: bool = (Input.is_key_pressed(KEY_SHIFT)) and moving
	var target: String = "walk" if moving else "idle"
	if _anim.has_animation(target) and _anim.current_animation != target:
		_anim.play(target)
	_anim.speed_scale = 1.8 if sprinting else 1.0


func _process(delta: float) -> void:
	if _camera == null:
		return
	var behind: Vector3 = -global_transform.basis.z
	var cam_target: Vector3 = global_position + Vector3(0.0, CAM_OFFSET.y, 0.0) + behind * -CAM_OFFSET.z
	_camera.global_position = _camera.global_position.lerp(cam_target, CAM_LERP)
	_camera.look_at(global_position + Vector3(0.0, 2.5, 0.0), Vector3.UP)
	if _cam_shake > 0.0:
		_cam_shake -= delta * 6.0
		var shake: float = maxf(_cam_shake, 0.0)
		_camera.h_offset = randf_range(-shake, shake) * 0.6
		_camera.v_offset = randf_range(-shake, shake) * 0.4
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
