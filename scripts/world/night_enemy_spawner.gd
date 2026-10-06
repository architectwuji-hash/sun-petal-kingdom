extends Node3D
# NightEnemySpawner
# Spawns hostile enemies at night, clears them at dawn.
# Wire enemy_scenes in the Inspector or via FantasyForest.tscn.
# Enemies burst-spawn when night starts, then trickle throughout the night.

@export var enemy_scenes: Array[PackedScene] = []
@export var max_enemies:    int   = 12
@export var spawn_min_dist: float = 30.0
@export var spawn_max_dist: float = 60.0
@export var spawn_interval: float = 20.0

var _player:        Node3D = null
var _enemies:       Array  = []
var _rng:           RandomNumberGenerator = RandomNumberGenerator.new()
var _is_night:      bool  = false
var _trickle_timer: float = 0.0
var _dnc:           Node  = null


func _ready() -> void:
	_rng.randomize()
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _player:
		push_warning("[NightEnemySpawner] No player found in group 'player'")
	_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc:
		_dnc.night_started.connect(_on_night_started)
		_dnc.day_started.connect(_on_day_started)
		_is_night = _dnc.is_night()
		if _is_night:
			_on_night_started()
	else:
		push_warning("[NightEnemySpawner] No DayNightCycle found in group 'day_night'")


func _process(delta: float) -> void:
	if not _is_night or not _player:
		return
	_trickle_timer -= delta
	if _trickle_timer <= 0.0:
		_trickle_timer = spawn_interval
		_prune_dead()
		_spawn_wave(3)


func _on_night_started() -> void:
	_is_night = true
	_trickle_timer = 3.0
	_prune_dead()
	_spawn_wave(6)


func _on_day_started() -> void:
	_is_night = false
	for enemy in _enemies:
		if is_instance_valid(enemy):
			var tw := (enemy as Node).create_tween()
			tw.tween_property(enemy, "scale", Vector3.ZERO, 1.8)
			tw.tween_callback(enemy.queue_free)
	_enemies.clear()


func _prune_dead() -> void:
	var i := _enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(_enemies[i]):
			_enemies.remove_at(i)
		i -= 1


func _spawn_wave(count: int) -> void:
	if enemy_scenes.is_empty():
		return
	var available_slots: int = max_enemies - _enemies.size()
	var to_spawn: int = min(count, available_slots)
	for _i in range(to_spawn):
		var pos: Vector3 = _pick_spawn_pos()
		if pos == Vector3.ZERO:
			continue
		var scene: PackedScene = enemy_scenes[_rng.randi() % enemy_scenes.size()]
		if scene == null:
			continue
		var instance: Node3D = scene.instantiate() as Node3D
		if instance == null:
			continue
		get_tree().current_scene.add_child(instance)
		instance.global_position = pos
		_enemies.append(instance)


func _pick_spawn_pos() -> Vector3:
	if not is_instance_valid(_player):
		return Vector3.ZERO
	var player_pos: Vector3 = _player.global_position
	var angle: float  = _rng.randf() * TAU
	var dist: float   = _rng.randf_range(spawn_min_dist, spawn_max_dist)
	var offset: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	var target: Vector3 = player_pos + offset

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		target + Vector3(0, 60, 0),
		target + Vector3(0, -60, 0),
		1
	)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	return result["position"]
