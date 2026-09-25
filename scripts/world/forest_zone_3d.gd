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
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/ForestSprite.tscn")
const HEAL_SCENE: PackedScene = preload("res://scenes/items/HealOrb.tscn")
const MAX_ENEMIES: int = 5
const RESPAWN_DELAY: float = 20.0
const DecorScenes: Array[PackedScene] = [
	preload("res://scenes/world/props/KenneyRocksHigh.tscn"),
	preload("res://scenes/world/props/KenneyRocksLow.tscn"),
	preload("res://scenes/world/props/KenneyStones.tscn"),
	preload("res://scenes/world/props/KenneyPlant.tscn"),
]

@onready var tree_root: Node3D = $TreeRoot
@onready var decor_root: Node3D = $DecorRoot
@onready var petal_root: Node3D = $PetalRoot
@onready var enemy_root: Node3D = $EnemyRoot
@onready var _player_dot: ColorRect = $MinimapLayer/MinimapPanel/PlayerDot
@onready var _player: CharacterBody3D = $Player3D
@onready var _health_bar: ProgressBar = $HUD/VBoxContainer/HealthBar
@onready var _petal_label: Label = $HUD/VBoxContainer/PetalLabel
@onready var _kill_label: Label = $HUD/VBoxContainer/KillLabel
@onready var _dialog_layer: CanvasLayer = $DialogLayer
@onready var _dialog_text: Label = $DialogLayer/PanelContainer/VBoxContainer/DialogText
@onready var _npc_name: Label = $DialogLayer/PanelContainer/VBoxContainer/NpcName
@onready var _village_npc: Node3D = $Village/NPC3D

var _suppress_npc_interact: bool = false
var petal_count: int = 0
var _overview_mode: bool = false
var _overview_cam: Camera3D = null
var _play_cam: Camera3D = null
var _active_enemies: Array[Node] = []
var _respawn_timer: float = 0.0
var _kill_count: int = 0


func is_npc_interact_suppressed() -> bool:
	return _suppress_npc_interact


func _ready() -> void:
	if get_tree().root.get_node_or_null("BGMusic") == null:
		var music := AudioStreamPlayer.new()
		music.name = "BGMusic"
		var bgm_stream: AudioStream = load("res://assets/audio/pixel_drift.mp3") as AudioStream
		music.stream = bgm_stream
		if bgm_stream is AudioStreamMP3:
			(bgm_stream as AudioStreamMP3).loop = true
		music.volume_db = -10.0
		music.autoplay = true
		get_tree().root.add_child(music)
		music.play()

	_dialog_layer.visible = false
	_village_npc.interact_requested.connect(_on_npc_interact)
	_player.health_changed.connect(_on_player_health_changed)
	_player.player_died.connect(_on_player_died)
	_health_bar.value = _player.health
	_spawn_trees()
	_spawn_decor()
	_spawn_petals()
	_spawn_heal_orbs(6)
	_spawn_enemies(3)
	_setup_minimap()
	_setup_overview_cam()


func _setup_minimap() -> void:
	pass


func _setup_overview_cam() -> void:
	_play_cam = get_node("Camera3D") as Camera3D
	_overview_cam = Camera3D.new()
	_overview_cam.name = "OverviewCam"
	_overview_cam.position = Vector3(0.0, 180.0, 0.0)
	_overview_cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_overview_cam.current = false
	add_child(_overview_cam)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		_overview_mode = not _overview_mode
		_overview_cam.current = _overview_mode
		_play_cam.current = not _overview_mode


func _process(delta: float) -> void:
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0 and _active_enemies.size() < MAX_ENEMIES:
			_spawn_one_enemy()

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


func _on_player_died() -> void:
	_show_game_over()


func _show_game_over() -> void:
	get_tree().paused = true
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.75)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -160
	vbox.offset_right = 160
	vbox.offset_top = -80
	vbox.offset_bottom = 80
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	overlay.add_child(vbox)
	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "The forest sprites got you."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(sub)
	var btn := Button.new()
	btn.text = "Try Again"
	btn.custom_minimum_size = Vector2(160, 44)
	btn.pressed.connect(_restart_game)
	vbox.add_child(btn)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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


func _spawn_enemies(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55555
	for _i: int in count:
		_spawn_one_enemy(rng)


func _spawn_one_enemy(rng: RandomNumberGenerator = null) -> void:
	var spawn_rng: RandomNumberGenerator = rng
	if spawn_rng == null:
		spawn_rng = RandomNumberGenerator.new()
		spawn_rng.seed = randi()
	var enemy: Node = ENEMY_SCENE.instantiate()
	var x: float = spawn_rng.randf_range(-150.0, 150.0)
	var z: float = spawn_rng.randf_range(-150.0, 150.0)
	if absf(x) < 25.0 and absf(z) < 25.0:
		if x != 0.0:
			x += 30.0 * sign(x)
		else:
			x = 30.0
	enemy.position = Vector3(x, 0.0, z)
	enemy.tree_exiting.connect(_on_enemy_removed)
	enemy_root.add_child(enemy)
	_active_enemies.append(enemy)


func _on_enemy_removed() -> void:
	_active_enemies = _active_enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
	_kill_count += 1
	if _kill_label != null:
		_kill_label.text = "☠ %d kills" % _kill_count
	_respawn_timer = RESPAWN_DELAY


func _spawn_heal_orbs(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777
	for _i: int in count:
		var orb: Node3D = HEAL_SCENE.instantiate()
		var x: float = rng.randf_range(-140.0, 140.0)
		var z: float = rng.randf_range(-140.0, 140.0)
		if absf(x) < 20.0 and absf(z) < 20.0:
			x += 25.0
		orb.position = Vector3(x, 0.4, z)
		orb.healed.connect(_on_orb_healed)
		add_child(orb)


func _on_orb_healed(_orb: Node3D) -> void:
	if is_instance_valid(_player) and _player.has_method("set_health"):
		_player.set_health(_player.health + 25)


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
