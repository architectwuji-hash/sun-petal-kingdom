extends Node3D

const TREE_COUNT: int = 60
const DECOR_COUNT: int = 20
const SPAWN_CLEAR_RADIUS: float = 20.0
const TREE_SEED: int = 91234
const DECOR_SEED: int = 91235

const TreeScene: PackedScene = preload("res://scenes/world/props/KenneyTree.tscn")
const TreeHighScene: PackedScene = preload("res://scenes/world/props/KenneyTreeHigh.tscn")

const DecorScenes: Array[PackedScene] = [
	preload("res://scenes/world/props/KenneyRocksHigh.tscn"),
	preload("res://scenes/world/props/KenneyRocksLow.tscn"),
	preload("res://scenes/world/props/KenneyStones.tscn"),
	preload("res://scenes/world/props/KenneyPlant.tscn"),
]

@onready var tree_root: Node3D = $TreeRoot
@onready var decor_root: Node3D = $DecorRoot
@onready var _player_dot: ColorRect = $MinimapLayer/MinimapPanel/PlayerDot
@onready var _player: CharacterBody3D = $Player3D


func _ready() -> void:
	_spawn_trees()
	_spawn_decor()


func _process(_delta: float) -> void:
	var world_pos: Vector3 = _player.global_position
	_player_dot.position = Vector2(
		((world_pos.x + 100.0) / 200.0) * 160.0 - 4.0,
		((world_pos.z + 100.0) / 200.0) * 160.0 - 4.0
	)


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var placed: int = 0
	var attempts: int = 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-90.0, 90.0),
			0.0,
			rng.randf_range(-90.0, 90.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var tree_scene: PackedScene = TreeHighScene if rng.randi() % 2 == 0 else TreeScene
		var tree: Node3D = tree_scene.instantiate()
		tree_root.add_child(tree)
		tree.global_position = pos
		placed += 1


func _spawn_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	var placed: int = 0
	var attempts: int = 0
	while placed < DECOR_COUNT and attempts < DECOR_COUNT * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-90.0, 90.0),
			0.0,
			rng.randf_range(-90.0, 90.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var decor_scene: PackedScene = DecorScenes[rng.randi() % DecorScenes.size()]
		var decor: Node3D = decor_scene.instantiate()
		decor_root.add_child(decor)
		decor.global_position = pos
		decor.rotation.y = rng.randf_range(0.0, TAU)
		placed += 1
