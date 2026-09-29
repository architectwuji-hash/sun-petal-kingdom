extends Node3D

var _player: Node3D = null
var _phase: String = "rising"   # rising → pausing → seeking
var _pause_timer: float = 0.0
var _bob_time: float = 0.0
var _rise_target_y: float = 0.0


func _ready() -> void:
	# Load the graveyard kit ghost model
	var ghost_scene: PackedScene = load("res://assets/models/items/kenney_graveyard/character-ghost.glb")
	if ghost_scene:
		var ghost := ghost_scene.instantiate()
		ghost.scale = Vector3(1.2, 1.2, 1.2)
		add_child(ghost)
	# Blue glow around the ghost
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.8, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)
	_rise_target_y = global_position.y + 4.5
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_bob_time += delta
	match _phase:
		"rising":
			global_position.y = move_toward(global_position.y, _rise_target_y, 6.0 * delta)
			if global_position.y >= _rise_target_y - 0.05:
				_phase = "pausing"
				_pause_timer = 1.0
		"pausing":
			global_position.y = _rise_target_y + sin(_bob_time * 4.0) * 0.12
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_phase = "seeking"
		"seeking":
			if _player == null:
				return
			var target := _player.global_position + Vector3(0, 1.2, 0)
			var dir := target - global_position
			if dir.length() < 0.4:
				if _player.has_method("absorb_soul"):
					_player.absorb_soul()
				queue_free()
				return
			var speed := lerpf(5.0, 14.0, 1.0 - clampf(dir.length() / 6.0, 0.0, 1.0))
			global_position += dir.normalized() * speed * delta
