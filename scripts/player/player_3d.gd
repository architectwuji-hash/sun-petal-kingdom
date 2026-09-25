extends CharacterBody3D

const SPEED: float = 8.0
const GRAVITY: float = 20.0
const CAM_OFFSET: Vector3 = Vector3(0.0, 20.0, 12.0)

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
@onready var _character_model: Node3D = $CharacterModel
@onready var _anim: AnimationPlayer = $CharacterModel/AnimationPlayer


func _ready() -> void:
	if _anim.has_animation("idle"):
		_anim.play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()

	global_position.x = clamp(global_position.x, -95.0, 95.0)
	global_position.z = clamp(global_position.z, -95.0, 95.0)

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
	_camera.global_position = _camera.global_position.lerp(global_position + CAM_OFFSET, 0.1)
	_camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
