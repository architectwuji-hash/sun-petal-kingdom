extends Node3D
## AnimalSpawner — dynamic proximity-based animal population manager.
## Keeps a fixed cap of wolves and deer alive near the player at all times.
## Animals spawn just outside the player's view, despawn when far away.
## Total active count stays capped so performance is predictable.

## ── Tuning ────────────────────────────────────────────────────────────────────
@export var wolf_scene:     PackedScene
@export var deer_scene:     PackedScene

@export var max_wolves:     int   = 8    ## Hard cap on simultaneously active wolves
@export var max_deer:       int   = 14   ## Hard cap on simultaneously active deer

@export var spawn_min_dist: float = 50.0 ## Closest distance from player to spawn (behind view)
@export var spawn_max_dist: float = 75.0 ## Farthest distance from player to spawn
@export var despawn_dist:   float = 100.0 ## Remove animals beyond this distance

@export var check_interval: float = 3.0  ## Seconds between population checks

## ── Internal ──────────────────────────────────────────────────────────────────
var _player:      Node3D = null
var _timer:       float  = 0.0
var _wolves:      Array[Node3D] = []
var _deer:        Array[Node3D] = []
var _rng:         RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	## Defer player lookup one frame so scene is fully loaded
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _player:
		push_warning("[AnimalSpawner] No player found in group 'player'")


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval

	_prune(_wolves)
	_prune(_deer)
	_fill_population(_wolves, max_wolves, wolf_scene)
	_fill_population(_deer,   max_deer,   deer_scene)


## Remove destroyed or too-far animals from the tracking array
func _prune(arr: Array[Node3D]) -> void:
	var player_pos := _player.global_position
	var i := arr.size() - 1
	while i >= 0:
		var a: Node3D = arr[i]
		if not is_instance_valid(a):
			arr.remove_at(i)
		elif player_pos.distance_to(a.global_position) > despawn_dist:
			a.queue_free()
			arr.remove_at(i)
		i -= 1


## Spawn animals until the cap is reached
func _fill_population(arr: Array[Node3D], cap: int, scene: PackedScene) -> void:
	if scene == null:
		return
	var needed := cap - arr.size()
	for _i in range(needed):
		var pos := _pick_spawn_pos()
		if pos == Vector3.ZERO:
			continue
		var instance: Node3D = scene.instantiate() as Node3D
		if instance == null:
			continue
		instance.global_position = pos
		get_tree().current_scene.add_child(instance)
		arr.append(instance)


## Pick a random position in the spawn ring around the player, on the ground
func _pick_spawn_pos() -> Vector3:
	if not is_instance_valid(_player):
		return Vector3.ZERO

	var player_pos := _player.global_position
	var angle   := _rng.randf() * TAU
	var dist    := _rng.randf_range(spawn_min_dist, spawn_max_dist)
	var offset  := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	var target  := player_pos + offset

	## Raycast downward to find the ground surface
	var space := get_world_3d().direct_space_state
	var ray_start := target + Vector3(0, 60, 0)
	var ray_end   := target + Vector3(0, -60, 0)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)  ## layer 1 = terrain
	var result := space.intersect_ray(query)
	if result.is_empty():
		## No ground found — skip this slot (water, void, etc.)
		return Vector3.ZERO

	return result["position"]
