extends Control


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_configure_bgm_loop($BGMusic)


func _on_play_pressed() -> void:
	var music: AudioStreamPlayer = $BGMusic
	music.reparent(get_tree().root)
	music.name = "BGMusic"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().change_scene_to_file("res://scenes/world/ForestZone3D.tscn")


func _configure_bgm_loop(player: AudioStreamPlayer) -> void:
	var stream: AudioStream = player.stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
