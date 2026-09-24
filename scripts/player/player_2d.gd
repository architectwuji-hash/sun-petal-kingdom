extends CharacterBody2D

const SPEED := 80.0

@onready var body:   AnimatedSprite2D = $Body
@onready var outfit: AnimatedSprite2D = $Outfit
@onready var hair:   AnimatedSprite2D = $Hair
@onready var hat:    AnimatedSprite2D = $Hat

var facing := "south"

func _ready() -> void:
	_play("idle_south")

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_back"):  dir.y += 1
	if Input.is_action_pressed("move_forward"): dir.y -= 1

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * SPEED
		if abs(dir.x) >= abs(dir.y):
			facing = "east" if dir.x > 0 else "west"
		else:
			facing = "south" if dir.y > 0 else "north"
		_play("walk_" + facing)
	else:
		velocity = Vector2.ZERO
		_play("idle_" + facing)

	move_and_slide()

func _play(anim: String) -> void:
	for node in [body, outfit, hair, hat]:
		if node != null and node.animation != anim:
			node.play(anim)
