extends Node3D

const TREE_COUNT: int = 60
const SPAWN_CLEAR_RADIUS: float = 8.0
const TREE_SEED: int = 91234

const TreeScene: PackedScene = preload("res://scenes/world/props/KenneyTree.tscn")
const TreeHighScene: PackedScene = preload("res://scenes/world/props/KenneyTreeHigh.tscn")

@onready var tree_root: Node3D = $TreeRoot
@onready var _player_dot: ColorRect = $MinimapLayer/MinimapPanel/PlayerDot
@onready var _player: CharacterBody3D = $Player3D


func _ready() -> void:
	_spawn_trees()


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
