extends CharacterBody3D

signal health_changed(new_val: int)

const SPEED: float = 12.0
const GRAVITY: float = 20.0
const CAM_OFFSET: Vector3 = Vector3(0.0, 5.0, 8.0)
const CAM_LERP: float = 0.12

@onready var _character_model: Node3D = $CharacterModel
@onready var _anim: AnimationPlayer = $CharacterModel/AnimationPlayer

var _camera: Camera3D
var health: int = 100


func _ready() -> void:
	_camera = get_parent().get_node("Camera3D")
	health_changed.emit(health)
	if _anim.has_animation("idle"):
		_anim.play("idle")


func set_health(value: int) -> void:
	var clamped: int = clampi(value, 0, 100)
	if health == clamped:
		return
	health = clamped
	health_changed.emit(health)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cam_basis: Basis = _camera.global_transform.basis
	var forward: Vector3 = -Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var direction: Vector3 = forward * -input_dir.y + right * input_dir.x
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()

	global_position.x = clamp(global_position.x, -195.0, 195.0)
	global_position.z = clamp(global_position.z, -195.0, 195.0)

	if velocity.length() > 0.1:
		_character_model.rotation.y = lerp_angle(
			_character_model.rotation.y,
			atan2(-velocity.x, -velocity.z),
			0.2
		)

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
	var target_pos: Vector3 = global_position + CAM_OFFSET
	_camera.global_position = _camera.global_position.lerp(target_pos, CAM_LERP)
	_camera.look_at(global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
