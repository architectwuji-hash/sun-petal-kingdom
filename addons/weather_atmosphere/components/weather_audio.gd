class_name WeatherAudio
extends Node

## Optional rain, wind, and thunder playback driven by WeatherProfile levels.
## Assign project-owned streams in the Inspector; the toolkit remains silent
## and fully functional when no audio resources are supplied.

@export var controller: WeatherController3D

@export_group("Looping Ambience")
@export var rain_stream: AudioStream
@export var wind_stream: AudioStream
@export var ambience_bus: StringName = &"Master"
@export_range(-80.0, 0.0, 0.5) var silent_db := -60.0

@export_group("Thunder")
@export var thunder_streams: Array[AudioStream] = []
@export var thunder_bus: StringName = &"Master"
@export_range(-24.0, 12.0, 0.5) var thunder_min_db := -8.0
@export_range(-24.0, 12.0, 0.5) var thunder_max_db := 0.0
@export_range(0.8, 1.2, 0.01) var thunder_pitch_min := 0.94
@export_range(0.8, 1.2, 0.01) var thunder_pitch_max := 1.06

var _rain_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _rain_level := 0.0
var _wind_level := 0.0


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherAudio requires a WeatherController3D.")
		return
	_rng.randomize()
	_rain_player = _create_player("RainAmbience", ambience_bus)
	_wind_player = _create_player("WindAmbience", ambience_bus)
	_thunder_player = _create_player("Thunder", thunder_bus)
	_rain_player.stream = rain_stream
	_wind_player.stream = wind_stream
	_rain_player.finished.connect(_restart_loop.bind(_rain_player))
	_wind_player.finished.connect(_restart_loop.bind(_wind_player))
	controller.state_changed.connect(_on_state_changed)
	controller.thunder_requested.connect(_on_thunder_requested)
	_on_state_changed(controller.get_effective_state())


func get_rain_level() -> float:
	return _rain_level


func get_wind_level() -> float:
	return _wind_level


func _create_player(node_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus_name
	player.volume_db = silent_db
	add_child(player)
	return player


func _on_state_changed(state: Dictionary) -> void:
	_rain_level = clampf(float(state.get("rain_audio_level", 0.0)), 0.0, 1.0)
	_wind_level = clampf(float(state.get("wind_audio_level", 0.0)), 0.0, 1.0)
	_apply_loop_level(_rain_player, _rain_level)
	_apply_loop_level(_wind_player, _wind_level)


func _apply_loop_level(player: AudioStreamPlayer, level: float) -> void:
	if player == null:
		return
	player.volume_db = silent_db if level <= 0.0001 else linear_to_db(level)
	if level > 0.0001 and player.stream != null and not player.playing:
		player.play()
	elif level <= 0.0001 and player.playing:
		player.stop()


func _restart_loop(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	var level := _rain_level if player == _rain_player else _wind_level
	if level > 0.0001:
		player.play()


func _on_thunder_requested(delay_seconds: float, strength: float) -> void:
	if thunder_streams.is_empty():
		return
	_play_thunder_after_delay(maxf(delay_seconds, 0.0), clampf(strength, 0.0, 1.0))


func _play_thunder_after_delay(delay_seconds: float, strength: float) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if not is_instance_valid(_thunder_player) or thunder_streams.is_empty():
		return
	_thunder_player.stream = thunder_streams[_rng.randi_range(0, thunder_streams.size() - 1)]
	_thunder_player.volume_db = lerpf(thunder_min_db, thunder_max_db, strength)
	_thunder_player.pitch_scale = _rng.randf_range(
		minf(thunder_pitch_min, thunder_pitch_max),
		maxf(thunder_pitch_min, thunder_pitch_max),
	)
	_thunder_player.play()
