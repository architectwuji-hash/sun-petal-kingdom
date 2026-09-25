extends Node3D

const TREE_COUNT: int = 60
const DECOR_COUNT: int = 20
const PETAL_COUNT: int = 10
const SPAWN_CLEAR_RADIUS: float = 20.0
const TREE_SEED: int = 91234
const DECOR_SEED: int = 91235
const PETAL_SEED: int = 91236

const TreeScene: PackedScene = preload("res://scenes/world/props/KenneyTree.tscn")
const TreeHighScene: PackedScene = preload("res://scenes/world/props/KenneyTreeHigh.tscn")
const PetalScene: PackedScene = preload("res://scenes/items/SunPetal.tscn")

const DecorScenes: Array[PackedScene] = [
	preload("res://scenes/world/props/KenneyRocksHigh.tscn"),
	preload("res://scenes/world/props/KenneyRocksLow.tscn"),
	preload("res://scenes/world/props/KenneyStones.tscn"),
	preload("res://scenes/world/props/KenneyPlant.tscn"),
]

@onready var tree_root: Node3D = $TreeRoot
@onready var decor_root: Node3D = $DecorRoot
@onready var petal_root: Node3D = $PetalRoot
@onready var _player_dot: ColorRect = $MinimapLayer/MinimapPanel/PlayerDot
@onready var _player: CharacterBody3D = $Player3D
@onready var _health_bar: ProgressBar = $HUD/VBoxContainer/HealthBar
@onready var _petal_label: Label = $HUD/VBoxContainer/PetalLabel
@onready var _dialog_layer: CanvasLayer = $DialogLayer
@onready var _dialog_text: Label = $DialogLayer/PanelContainer/VBoxContainer/DialogText
@onready var _npc_name: Label = $DialogLayer/PanelContainer/VBoxContainer/NpcName
@onready var _village_npc: Node3D = $Village/NPC3D

var _suppress_npc_interact: bool = false
var petal_count: int = 0


func is_npc_interact_suppressed() -> bool:
	return _suppress_npc_interact


func _ready() -> void:
	_dialog_layer.visible = false
	_village_npc.interact_requested.connect(_on_npc_interact)
	_player.health_changed.connect(_on_player_health_changed)
	_health_bar.value = _player.health
	_spawn_trees()
	_spawn_decor()
	_spawn_petals()


func _process(_delta: float) -> void:
	if _dialog_layer.visible and Input.is_action_just_pressed("ui_accept"):
		_dialog_layer.visible = false
		_suppress_npc_interact = true
		call_deferred("_reset_npc_interact_suppress")
		return

	var world_pos: Vector3 = _player.global_position
	_player_dot.position = Vector2(
		((world_pos.x + 200.0) / 400.0) * 160.0 - 4.0,
		((world_pos.z + 200.0) / 400.0) * 160.0 - 4.0
	)


func _on_player_health_changed(val: int) -> void:
	_health_bar.value = val


func _on_npc_interact(_npc: Node3D) -> void:
	if _suppress_npc_interact:
		return
	_npc_name.text = "Village Elder"
	_dialog_layer.visible = true
	_dialog_text.text = "Welcome to the forest, traveler. The path ahead is dangerous."


func _on_petal_collected(_petal: Node3D) -> void:
	petal_count += 1
	_petal_label.text = "🌸 %d / %d" % [petal_count, PETAL_COUNT]
	if petal_count >= PETAL_COUNT:
		_on_all_petals_collected()


func _on_all_petals_collected() -> void:
	_npc_name.text = "Sun Petal Kingdom"
	_dialog_text.text = "You have gathered all 10 sun petals. The forest is restored."
	_dialog_layer.visible = true


func _reset_npc_interact_suppress() -> void:
	_suppress_npc_interact = false


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var placed: int = 0
	var attempts: int = 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-150.0, 150.0),
			0.0,
			rng.randf_range(-150.0, 150.0)
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
			rng.randf_range(-150.0, 150.0),
			0.0,
			rng.randf_range(-150.0, 150.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var decor_scene: PackedScene = DecorScenes[rng.randi() % DecorScenes.size()]
		var decor: Node3D = decor_scene.instantiate()
		decor_root.add_child(decor)
		decor.global_position = pos
		decor.rotation.y = rng.randf_range(0.0, TAU)
		placed += 1
	# TODO: KenneyRocksHigh uses StaticBody3D only (no Area3D) — add hurt zones for rock damage.


func _spawn_petals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PETAL_SEED
	var placed: int = 0
	var attempts: int = 0
	while placed < PETAL_COUNT and attempts < PETAL_COUNT * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-80.0, 80.0),
			0.6,
			rng.randf_range(-80.0, 80.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var petal: Node3D = PetalScene.instantiate()
		petal.collected.connect(_on_petal_collected)
		petal_root.add_child(petal)
		petal.global_position = pos
		placed += 1
