extends Control


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var stream: AudioStream = $BGMusic.stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _on_play_pressed() -> void:
	var music: AudioStreamPlayer = $BGMusic
	remove_child(music)
	get_tree().root.add_child(music)
	music.name = "BGMusic"
	get_tree().change_scene_to_file("res://scenes/world/ForestZone3D.tscn")
