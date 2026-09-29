extends Node3D

const BOAT_SPEED: float      = 10.0
const BOAT_REVERSE: float    = 4.0
const BOAT_TURN_SPEED: float = 1.8

var _occupied: bool    = false
var _player: Node3D    = null
var _water_y: float    = 0.0
var _label: Label3D    = null

func _ready() -> void:
	add_to_group("interactable")
	_water_y = global_position.y

	var detect := Area3D.new()
	detect.collision_layer = 0
	detect.collision_mask  = 2
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 6.0
	cs.shape = sp
	detect.add_child(cs)
	add_child(detect)
	detect.body_entered.connect(_on_near)
	detect.body_exited.connect(_on_far)

	_label = Label3D.new()
	_label.text       = "[E] Board"
	_label.position   = Vector3(0, 4, 0)
	_label.pixel_size = 0.015
	_label.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	_label.visible    = false
	add_child(_label)

func _on_near(body: Node3D) -> void:
	if body.is_in_group("player"):
		_label.visible = true

func _on_far(body: Node3D) -> void:
	if body.is_in_group("player"):
		if not _occupied:
			_label.visible = false

func interact(player: Node3D) -> void:
	if _occupied:
		_exit()
	else:
		_board(player)

func _board(player: Node3D) -> void:
	_occupied = true
	_player   = player
	player.set_physics_process(false)
	var model := player.get_node_or_null("CharacterModel")
	if model:
		model.visible = false
	_label.text = "[E] Exit"

func _exit() -> void:
	if _player:
		_player.set_physics_process(true)
		var model := _player.get_node_or_null("CharacterModel")
		if model:
			model.visible = true
		_player.global_position   = global_position + global_transform.basis.x * 5.0
		_player.global_position.y = 0.0
		_player.velocity          = Vector3.ZERO
		_player = null
	_occupied      = false
	_label.text    = "[E] Board"
	_label.visible = false

func _process(delta: float) -> void:
	if not _occupied:
		return

	var turn := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn =  1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn = -1.0
	rotation.y += turn * BOAT_TURN_SPEED * delta

	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle =  1.0
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle = -0.4

	var forward := -global_transform.basis.z
	global_position += forward * throttle * BOAT_SPEED * delta
	global_position.y = _water_y

	if _player:
		_player.global_position = global_position + Vector3(0, 1.5, 0)
		_player.rotation.y      = rotation.y
