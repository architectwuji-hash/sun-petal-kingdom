extends CharacterBody3D

const SPEED: float = 8.0
const GRAVITY: float = 20.0
const CAMERA_OFFSET: Vector3 = Vector3(0.0, 20.0, 12.0)

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")


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
	_camera.global_position = global_position + CAMERA_OFFSET
