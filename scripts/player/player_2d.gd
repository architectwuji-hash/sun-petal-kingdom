extends CharacterBody2D

const SPEED = 80.0

@onready var body = $Body
@onready var outfit = $Outfit
@onready var hair = $Hair
@onready var hat = $Hat

var facing := "south"


func _ready() -> void:
	play_anim("idle_south")


func _physics_process(_delta: float) -> void:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * SPEED
		if abs(dir.x) >= abs(dir.y):
			facing = "east" if dir.x > 0 else "west"
		else:
			facing = "south" if dir.y > 0 else "north"
		play_anim("walk_" + facing)
	else:
		velocity = Vector2.ZERO
		play_anim("idle_" + facing)

	move_and_slide()


func play_anim(anim_name: String) -> void:
	for node in [body, outfit, hair, hat]:
		if node.animation != anim_name:
			node.play(anim_name)
			node.frame = body.frame
