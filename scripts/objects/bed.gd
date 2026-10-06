extends Node3D
## Bed — press [E] to sleep and skip to morning.
## Attach to any bed mesh in the world.
## Requires a DayNightCycle node in the "day_night" group.

const INTERACT_RANGE := 3.0
const LABEL_HEIGHT   := 1.6

var _sleeping        := false
var _label: Label3D  = null
var _player_ref: Node = null

func _ready() -> void:
	add_to_group("interactable")
	_label = Label3D.new()
	_label.text      = "[E] Sleep"
	_label.position  = Vector3(0, LABEL_HEIGHT, 0)
	_label.font_size = 26
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate  = Color(0.7, 0.9, 1.0)
	_label.visible   = false
	_label.name      = "SleepLabel"
	add_child(_label)


func _process(_delta: float) -> void:
	if _sleeping:
		return
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref == null:
		return
	var dist: float = global_position.distance_to((_player_ref as Node3D).global_position)
	if _label:
		_label.visible = dist < INTERACT_RANGE + 1.5


## Called by the player interact system when [E] is pressed.
func interact(player: Node) -> void:
	if _sleeping:
		return
	var dnc: Node = get_tree().get_first_node_in_group("day_night")
	if dnc == null:
		_flash_message(player, "No day/night cycle found.")
		return
	var is_night: bool = dnc.call("is_night")
	if not is_night:
		_flash_message(player, "You can only sleep at night.")
		return

	_sleeping = true
	if _label:
		_label.visible = false

	# Fade to black, skip time, fade back.
	_do_sleep(player, dnc)


func _do_sleep(player: Node, dnc: Node) -> void:
	# Create a full-screen black overlay on the player node.
	var cl := CanvasLayer.new()
	cl.layer = 30
	var rect := ColorRect.new()
	rect.color       = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)
	player.add_child(cl)

	var tw := create_tween()
	# Fade in
	tw.tween_property(rect, "color", Color(0, 0, 0, 1), 0.8)
	# Skip to dawn while screen is black
	tw.tween_callback(func():
		dnc.set("time", dnc.get("start_time"))
		# Extinguish player's torch if they had one lit
		if player.has_method("_extinguish_torch"):
			player.call("_extinguish_torch")
	)
	tw.tween_interval(0.5)
	# Fade back
	tw.tween_property(rect, "color", Color(0, 0, 0, 0), 1.2)
	tw.tween_callback(func():
		cl.queue_free()
		_sleeping = false
		if _label:
			_label.visible = false
	)


func _flash_message(player: Node, msg: String) -> void:
	if player.has_method("_show_hud_message"):
		player.call("_show_hud_message", msg)
