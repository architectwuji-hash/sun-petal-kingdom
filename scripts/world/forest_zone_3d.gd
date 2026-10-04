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
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/PlantMonster.tscn")
const HEAL_SCENE: PackedScene = preload("res://scenes/items/HealOrb.tscn")
const MAX_ENEMIES: int = 5
const RESPAWN_DELAY: float = 20.0
const HarvestableRockScene: PackedScene = preload("res://scenes/objects/HarvestableRock.tscn")
const ROCK_COUNT: int = 16
const MUSHROOM_COUNT: int = 12
const MUSHROOM_RESPAWN_TIME: float = 45.0
const DecorScenes: Array[PackedScene] = [
	preload("res://scenes/world/props/KenneyRocksHigh.tscn"),
	preload("res://scenes/world/props/KenneyRocksLow.tscn"),
	preload("res://scenes/world/props/KenneyStones.tscn"),
	preload("res://scenes/world/props/KenneyPlant.tscn"),
]

var tree_root: Node3D = null
var decor_root: Node3D = null
var petal_root: Node3D = null
var enemy_root: Node3D = null
@onready var _player_dot: ColorRect = $MinimapLayer/MinimapPanel/PlayerDot
var _player: CharacterBody3D = null
@onready var _health_bar: ProgressBar = get_node_or_null("HUD_VBoxContainer#HealthBar") as ProgressBar
@onready var _petal_label: Label = get_node_or_null("HUD_VBoxContainer#PetalLabel") as Label
@onready var _kill_label: Label = get_node_or_null("HUD_VBoxContainer#KillLabel") as Label
@onready var _dialog_layer: CanvasLayer = $DialogLayer
@onready var _dialog_text: Label = $DialogLayer/PanelContainer/VBoxContainer/DialogText
@onready var _npc_name: Label = $DialogLayer/PanelContainer/VBoxContainer/NpcName
var _village_npc: Node3D = null

var _suppress_npc_interact: bool = false
var _res_labels: Dictionary = {}   ## "wood" → Label, "stone" → Label, "mushroom" → Label
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
	_setup_bg_music.call_deferred()

	_dialog_layer.visible = false
	if has_node("Village/NPC3D"):
		_village_npc = get_node("Village/NPC3D") as Node3D
		_village_npc.interact_requested.connect(_on_npc_interact)
	if has_node("Player3D"):
		_player = get_node("Player3D") as CharacterBody3D
		_player.health_changed.connect(_on_player_health_changed)
		_player.player_died.connect(_on_player_died)
		if _player.has_signal("inventory_changed"):
			_player.inventory_changed.connect(_on_inventory_changed)
		if _health_bar != null:
			_health_bar.value = _player.health
	# 3-minute day/night cycle (drives the Sun + WorldEnvironment in this scene)
	var day_night: Node = preload("res://scripts/world/day_night_cycle.gd").new()
	day_night.name = "DayNightCycle"
	add_child(day_night)
	# Weather system — automatically picks from presets based on time
	var weather_scene: PackedScene = load("res://addons/weather_atmosphere/weather_system_3d.tscn")
	if weather_scene:
		var weather := weather_scene.instantiate()
		weather.name = "WeatherSystem"
		# Keep enough fog that trees fade out before the draw-distance cutoff
		if "min_fog_density" in weather:
			weather.min_fog_density = 0.014
		add_child(weather)
	#_spawn_trees()
	#_spawn_decor()
	#_spawn_petals()
	#_spawn_heal_orbs(6)
	#_spawn_enemies(3)
	_setup_minimap()
	_setup_overview_cam()
	_spawn_rocks()
	_spawn_mushrooms()
	_setup_resource_panel()



func _setup_bg_music() -> void:
	if get_tree().root.get_node_or_null("BGMusic") != null:
		return
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

func _setup_minimap() -> void:
	pass


func _setup_overview_cam() -> void:
	# Static Camera3D was removed from scene; player_3d.gd builds its own follow-cam.
	# _play_cam is grabbed lazily from the viewport when Tab is pressed.
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
		# Grab the player's camera from the viewport if we don't have it yet
		if _play_cam == null:
			_play_cam = get_viewport().get_camera_3d()
		if _play_cam != null:
			_play_cam.current = not _overview_mode


func _process(delta: float) -> void:
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0 and _active_enemies.size() < MAX_ENEMIES:
			_spawn_one_enemy()

	if _dialog_layer.visible and Input.is_key_pressed(KEY_E):
		_dialog_layer.visible = false
		_suppress_npc_interact = true
		call_deferred("_reset_npc_interact_suppress")
		return

	if _player != null:
		var world_pos: Vector3 = _player.global_position
		_player_dot.position = Vector2(
			((world_pos.x + 200.0) / 400.0) * 160.0 - 4.0,
			((world_pos.z + 200.0) / 400.0) * 160.0 - 4.0
		)


func _on_player_health_changed(val: int, max_val: int) -> void:
	if _health_bar != null:
		_health_bar.max_value = max_val
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
			rng.randf_range(-300.0, 300.0),
			0.0,
			rng.randf_range(-300.0, 300.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var tree_scene: PackedScene = TreeHighScene if rng.randi() % 2 == 0 else TreeScene
		var tree: Node3D = tree_scene.instantiate()
		if tree_root != null: tree_root.add_child(tree)
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
			rng.randf_range(-300.0, 300.0),
			0.0,
			rng.randf_range(-300.0, 300.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var decor_scene: PackedScene = DecorScenes[rng.randi() % DecorScenes.size()]
		var decor: Node3D = decor_scene.instantiate()
		if decor_root != null: decor_root.add_child(decor)
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
	var scene_to_use: PackedScene = ENEMY_SCENE
	var enemy: Node = scene_to_use.instantiate()
	var x: float = spawn_rng.randf_range(-300.0, 300.0)
	var z: float = spawn_rng.randf_range(-300.0, 300.0)
	if absf(x) < 25.0 and absf(z) < 25.0:
		if x != 0.0:
			x += 30.0 * sign(x)
		else:
			x = 30.0
	enemy.position = Vector3(x, 0.0, z)
	enemy.tree_exiting.connect(_on_enemy_removed)
	if enemy_root != null: enemy_root.add_child(enemy)
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
		var x: float = rng.randf_range(-290.0, 290.0)
		var z: float = rng.randf_range(-290.0, 290.0)
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
			rng.randf_range(-160.0, 160.0),
			0.6,
			rng.randf_range(-160.0, 160.0)
		)
		if Vector2(pos.x, pos.z).length() < SPAWN_CLEAR_RADIUS:
			continue
		var petal: Node3D = PetalScene.instantiate()
		petal.collected.connect(_on_petal_collected)
		if petal_root != null: petal_root.add_child(petal)
		petal.global_position = pos
		placed += 1


# ─── Resource System ──────────────────────────────────────────────────────────

func _spawn_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77341
	for i: int in ROCK_COUNT:
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(25.0, 250.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		# keep rocks out of the centre spawn area
		if pos.length() < 20.0:
			continue
		var rock: Node3D = HarvestableRockScene.instantiate()
		add_child(rock)
		rock.global_position = pos
		rock.rotation.y = rng.randf_range(0.0, TAU)


func _spawn_mushrooms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88812
	var placed: int = 0
	var attempts: int = 0
	while placed < MUSHROOM_COUNT and attempts < MUSHROOM_COUNT * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-240.0, 240.0),
			0.0,
			rng.randf_range(-240.0, 240.0)
		)
		if Vector2(pos.x, pos.z).length() < 18.0:
			continue
		_place_mushroom(pos)
		placed += 1


func _place_mushroom(pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = "MushroomPickup"
	area.collision_layer = 0
	area.collision_mask = 2
	add_child(area)
	area.global_position = pos

	# Stem
	var stem_mesh := MeshInstance3D.new()
	var stem := CylinderMesh.new()
	stem.top_radius    = 0.08
	stem.bottom_radius = 0.10
	stem.height        = 0.35
	stem_mesh.mesh = stem
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.95, 0.90, 0.85)
	stem_mesh.set_surface_override_material(0, stem_mat)
	stem_mesh.position.y = 0.175
	area.add_child(stem_mesh)

	# Cap
	var cap_mesh := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.22
	cap.height = 0.30
	cap_mesh.mesh = cap
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.85, 0.25, 0.10)
	cap_mesh.set_surface_override_material(0, cap_mat)
	cap_mesh.position.y = 0.42
	area.add_child(cap_mesh)

	# Glow
	var light := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.55, 0.15)
	light.light_energy = 0.6
	light.omni_range   = 1.2
	light.position.y   = 0.45
	area.add_child(light)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	area.add_child(col)

	area.body_entered.connect(_on_mushroom_entered.bind(area))


func _on_mushroom_entered(body: Node3D, area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("add_item"):
		return
	area.visible = false
	for child: Node in area.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	body.add_item("mushroom")
	_spawn_pickup_sparkle(area.global_position, Color(1.0, 0.6, 0.2))
	get_tree().create_timer(MUSHROOM_RESPAWN_TIME).timeout.connect(func() -> void:
		if is_instance_valid(area):
			area.visible = true
			for child: Node in area.get_children():
				if child is CollisionShape3D:
					(child as CollisionShape3D).disabled = false
	)


func _spawn_pickup_sparkle(at: Vector3, color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting        = true
	particles.one_shot        = true
	particles.explosiveness   = 1.0
	particles.amount          = 20
	particles.lifetime        = 0.6
	particles.spread          = 60.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.0
	particles.gravity         = Vector3(0, -4, 0)
	particles.color           = color
	add_child(particles)
	particles.global_position = at
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _setup_resource_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ResourceCanvas"
	canvas.layer = 10
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left   = -180.0
	panel.offset_top    = -110.0
	panel.offset_right  = -10.0
	panel.offset_bottom = -10.0
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	margin.add_child(inner)

	for entry: Array in [["🪵 Wood", "wood"], ["🪨 Stone", "stone"], ["🍄 Shroom", "mushroom"]]:
		var lbl := Label.new()
		lbl.text = entry[0] + ": 0"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.modulate = Color(0.95, 0.95, 0.85)
		inner.add_child(lbl)
		_res_labels[entry[1]] = lbl


func _on_inventory_changed(item: String, new_count: int) -> void:
	if _res_labels.has(item):
		var icons: Dictionary = {"wood": "🪵 Wood", "stone": "🪨 Stone", "mushroom": "🍄 Shroom"}
		var prefix: String = icons.get(item, item.capitalize())
		(_res_labels[item] as Label).text = "%s: %d" % [prefix, new_count]
