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
	_spawn_demon_npc()
	_spawn_auros_shrine()



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


# ─── Soul System: Demon NPC & Auros Shrine ───────────────────────────────────

var _soul_menu: Control       = null   ## the popup panel
var _soul_menu_type: String   = ""     ## "demon" or "auros"
var _companion: Node3D        = null   ## active companion (demon or angel)

func _spawn_demon_npc() -> void:
	var body := StaticBody3D.new()
	body.name = "DemonNPC"
	add_child(body)
	body.global_position = Vector3(60.0, 0.0, -40.0)

	# Visual — dark humanoid shape
	var mesh_inst := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	mesh_inst.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color    = Color(0.08, 0.0, 0.12)
	mat.emission_enabled = true
	mat.emission        = Color(0.6, 0.0, 1.0)
	mat.emission_energy = 1.2
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position.y = 0.9
	body.add_child(mesh_inst)

	# Eye glow
	var eye := OmniLight3D.new()
	eye.light_color  = Color(1.0, 0.0, 0.3)
	eye.light_energy = 2.0
	eye.omni_range   = 3.0
	eye.position.y   = 1.5
	body.add_child(eye)

	# Name label
	var label3d := Label3D.new()
	label3d.text       = "😈 Demon\n[E] Deal"
	label3d.font_size  = 32
	label3d.modulate   = Color(1.0, 0.3, 1.0)
	label3d.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position.y = 2.4
	body.add_child(label3d)

	# Collision
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	body.add_child(col)

	# Interaction area
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	body.add_child(area)
	var acol := CollisionShape3D.new()
	var asphere := SphereShape3D.new()
	asphere.radius = 3.0
	acol.shape = asphere
	area.add_child(acol)
	area.body_entered.connect(_on_demon_area_entered)
	area.body_exited.connect(_on_soul_area_exited)


func _spawn_auros_shrine() -> void:
	var body := StaticBody3D.new()
	body.name = "AurosShrine"
	add_child(body)
	body.global_position = Vector3(-55.0, 0.0, -50.0)

	# Base plinth
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.5, 1.4)
	plinth.mesh = box
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.85, 0.80, 0.65)
	plinth.set_surface_override_material(0, stone_mat)
	plinth.position.y = 0.25
	body.add_child(plinth)

	# Pillar
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.15
	cyl.bottom_radius = 0.18
	cyl.height        = 1.8
	pillar.mesh = cyl
	pillar.set_surface_override_material(0, stone_mat)
	pillar.position.y = 1.4
	body.add_child(pillar)

	# Sun disc on top
	var disc := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.35
	disc.mesh = sphere
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color     = Color(1.0, 0.85, 0.2)
	sun_mat.emission_enabled = true
	sun_mat.emission         = Color(1.0, 0.75, 0.1)
	sun_mat.emission_energy  = 2.0
	disc.set_surface_override_material(0, sun_mat)
	disc.position.y = 2.65
	body.add_child(disc)

	# Shrine glow
	var light := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.9, 0.3)
	light.light_energy = 1.5
	light.omni_range   = 5.0
	light.position.y   = 2.65
	body.add_child(light)

	# Label
	var label3d := Label3D.new()
	label3d.text      = "☀ Auros Shrine\n[E] Sacrifice"
	label3d.font_size = 32
	label3d.modulate  = Color(1.0, 0.95, 0.4)
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position.y = 3.3
	body.add_child(label3d)

	# Collision for body
	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(1.4, 2.8, 1.4)
	col.shape = cshape
	col.position.y = 1.4
	body.add_child(col)

	# Interaction area
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	body.add_child(area)
	var acol := CollisionShape3D.new()
	var asphere := SphereShape3D.new()
	asphere.radius = 3.0
	acol.shape = asphere
	area.add_child(acol)
	area.body_entered.connect(_on_auros_area_entered)
	area.body_exited.connect(_on_soul_area_exited)


func _on_demon_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_open_soul_menu("demon")

func _on_auros_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_open_soul_menu("auros")

func _on_soul_area_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_close_soul_menu()


func _open_soul_menu(menu_type: String) -> void:
	if _soul_menu != null:
		return
	_soul_menu_type = menu_type
	var canvas := CanvasLayer.new()
	canvas.name  = "SoulMenuCanvas"
	canvas.layer = 20
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -200.0
	panel.offset_right  = 200.0
	panel.offset_top    = -220.0
	panel.offset_bottom = 120.0
	canvas.add_child(panel)
	_soul_menu = panel

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	if menu_type == "demon":
		title.text    = "😈  Demon Deal"
		title.modulate = Color(0.9, 0.4, 1.0)
	else:
		title.text    = "☀  Auros Shrine"
		title.modulate = Color(1.0, 0.95, 0.3)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var soul_lbl := Label.new()
	var soul_count: int = _player.inventory.get("souls", 0) if is_instance_valid(_player) else 0
	soul_lbl.text = "Souls: %d" % soul_count
	soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(soul_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var options: Array[Array] = []
	if menu_type == "demon":
		options = [
			["Fear Aura (10 souls)",    10,  "fear_aura"],
			["Shadow Step (20 souls)",  20,  "shadow_step"],
			["Summon Demon (25 souls)", 25,  "summon_demon"],
			["World Intel (10 souls)",  10,  "world_intel"],
		]
	else:
		options = [
			["Solar Burst (10 souls)",   10, "solar_burst"],
			["Healing Aura (20 souls)",  20, "healing_aura"],
			["Summon Angel (25 souls)",  25, "summon_angel"],
			["Favor Offering (any)",      1, "favor_offering"],
		]

	for opt: Array in options:
		var btn := Button.new()
		btn.text = opt[0] as String
		btn.add_theme_font_size_override("font_size", 13)
		vbox.add_child(btn)
		var cost: int      = opt[1] as int
		var action: String = opt[2] as String
		btn.pressed.connect(_on_soul_option.bind(action, cost))

	var close_btn := Button.new()
	close_btn.text = "Leave"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(close_btn)
	close_btn.pressed.connect(_close_soul_menu)


func _close_soul_menu() -> void:
	if _soul_menu == null:
		return
	var canvas: Node = _soul_menu.get_parent()
	_soul_menu = null
	_soul_menu_type = ""
	if is_instance_valid(canvas):
		canvas.queue_free()


func _on_soul_option(action: String, cost: int) -> void:
	if not is_instance_valid(_player):
		return
	var soul_count: int = _player.inventory.get("souls", 0)
	if soul_count < cost:
		return

	match action:
		"fear_aura":
			if _player.sell_souls(cost):
				_show_dark_flash()
				print("Fear Aura activated!")
		"shadow_step":
			if _player.sell_souls(cost):
				_show_dark_flash()
				print("Shadow Step unlocked!")
		"summon_demon":
			if _player.sell_souls(cost):
				_summon_companion("demon")
		"world_intel":
			if _player.sell_souls(cost):
				print("World Intel: enemies revealed!")
		"solar_burst":
			if _player.sacrifice_souls(cost):
				_show_light_flash()
				print("Solar Burst activated!")
		"healing_aura":
			if _player.sacrifice_souls(cost):
				_player.set_health(_player.health + 40)
				_show_light_flash()
				print("Healing Aura!")
		"summon_angel":
			if _player.sacrifice_souls(cost):
				_summon_companion("angel")
		"favor_offering":
			if _player.sacrifice_souls(cost):
				print("Auros Favor offered.")

	_close_soul_menu()


func _summon_companion(kind: String) -> void:
	# Dismiss existing companion
	if is_instance_valid(_companion):
		_companion.queue_free()
		_companion = null

	var body := CharacterBody3D.new()
	body.name = "Companion_" + kind
	add_child(body)
	if is_instance_valid(_player):
		body.global_position = _player.global_position + Vector3(2.0, 0.0, 0.0)

	# Visual
	var mesh_inst := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.5
	mesh_inst.mesh = cap
	var mat := StandardMaterial3D.new()
	if kind == "demon":
		mat.albedo_color     = Color(0.15, 0.0, 0.25)
		mat.emission_enabled = true
		mat.emission         = Color(0.8, 0.0, 0.9)
		mat.emission_energy  = 1.0
	else:
		mat.albedo_color     = Color(1.0, 0.95, 0.7)
		mat.emission_enabled = true
		mat.emission         = Color(1.0, 0.9, 0.3)
		mat.emission_energy  = 1.5
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position.y = 0.75
	body.add_child(mesh_inst)

	# Glow
	var light := OmniLight3D.new()
	light.light_color  = Color(0.8, 0.0, 1.0) if kind == "demon" else Color(1.0, 0.95, 0.3)
	light.light_energy = 1.2
	light.omni_range   = 2.5
	light.position.y   = 0.9
	body.add_child(light)

	# Label
	var label3d := Label3D.new()
	label3d.text      = "😈" if kind == "demon" else "😇"
	label3d.font_size = 48
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position.y = 2.0
	body.add_child(label3d)

	# Collision
	var col := CollisionShape3D.new()
	var cshape := CapsuleShape3D.new()
	cshape.radius = 0.3
	cshape.height = 1.5
	col.shape = cshape
	col.position.y = 0.75
	body.add_child(col)

	_companion = body
	_spawn_pickup_sparkle(body.global_position, Color(0.8, 0.0, 1.0) if kind == "demon" else Color(1.0, 0.9, 0.2))

	# Companion follows player via timer
	var follow_timer := Timer.new()
	follow_timer.wait_time = 0.1
	follow_timer.autostart = true
	body.add_child(follow_timer)
	follow_timer.timeout.connect(func() -> void:
		if not is_instance_valid(body) or not is_instance_valid(_player):
			return
		var target: Vector3 = _player.global_position + Vector3(1.8, 0.0, 1.8)
		var dir: Vector3 = (target - body.global_position)
		if dir.length() > 2.0:
			body.velocity = dir.normalized() * 5.0
			body.move_and_slide()
	)

	# Auto-dismiss after 5 minutes
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free()
		if _companion == body:
			_companion = null
	)

	var name_str: String = "Demon Companion" if kind == "demon" else "Angel Companion"
	print(name_str, " summoned!")


func _show_dark_flash() -> void:
	_spawn_pickup_sparkle(_player.global_position + Vector3(0, 1, 0), Color(0.6, 0.0, 0.9))

func _show_light_flash() -> void:
	_spawn_pickup_sparkle(_player.global_position + Vector3(0, 1, 0), Color(1.0, 0.95, 0.3))


func _on_dark_tier_changed(tier: int) -> void:
	var names: Array[String] = ["Tainted", "Corrupted", "Infernal", "Damned", "Forsaken", "Hellbound"]
	print("🔴 Dark Tier %d: %s" % [tier, names[tier - 1]])
	_apply_dark_tier_rewards(tier)

func _apply_dark_tier_rewards(tier: int) -> void:
	## Tier 3+ — random demons start joining fights instead of attacking.
	## We flag this globally so any demon NPC spawned later checks it.
	if tier >= 3:
		get_tree().set_meta("dark_tier", tier)
		get_tree().call_group("demon_enemy", "on_dark_tier_raised", tier)

	## Tier 4 — Demon King becomes a permanent companion.
	if tier == 4:
		_summon_companion("demon_king")
		_show_hud_message("😈 The Demon King has pledged himself to you.")

	## Tier 5 — pack of 3 minor demons follows the player.
	if tier == 5:
		for _i: int in 3:
			_summon_companion("demon_minor")
		_show_hud_message("😈 A pack of minor demons now follows you.")

	## Tier 6 — Hellbound. All demons fight for you.
	if tier == 6:
		get_tree().set_meta("dark_tier", 6)
		get_tree().call_group("demon_enemy", "on_dark_tier_raised", 6)
		_show_hud_message("👑 You are their ruler. ALL demons fight for you.")

func _on_divine_tier_changed(tier: int) -> void:
	var names: Array[String] = ["Acknowledged", "Devoted", "Chosen", "Blessed", "Sacred", "Divine"]
	print("☀ Divine Tier %d: %s" % [tier, names[tier - 1]])
	_apply_divine_tier_rewards(tier)

func _apply_divine_tier_rewards(tier: int) -> void:
	## Tier 1 — +10% attack (handled in player_3d via divine_bonus).
	if tier == 1:
		_show_hud_message("☀ Auros acknowledges you. +10% attack.")

	## Tier 2 — +20% attack.
	if tier == 2:
		_show_hud_message("☀ Auros blesses you. +20% attack.")

	## Tier 3 — +35% attack, golden bird placeholder.
	if tier == 3:
		_show_hud_message("☀ A golden messenger bird now follows you. +35% attack.")
		## TODO: spawn golden bird NPC when asset is ready

	## Tier 4 — +50% attack, Dark Protection (evil attacks 40% less damage).
	if tier == 4:
		if is_instance_valid(_player) and _player.has_method("set"):
			_player.dark_protection_percent = 40
		_show_hud_message("☀ Blessed by Auros. +50% attack. Evil attacks deal 40%% less damage.")

	## Tier 5 — +65% attack, demons begin fleeing.
	if tier >= 5:
		get_tree().set_meta("divine_tier", tier)
		get_tree().call_group("demon_enemy", "on_divine_tier_raised", tier)
	if tier == 5:
		_show_hud_message("☀ Sacred. Demons flee before you. +65% attack.")

	## Tier 6 — +100% attack (double damage), Angel Champion, all demons flee, world blooms.
	if tier == 6:
		_summon_companion("angel_champion")
		get_tree().set_meta("divine_tier", 6)
		get_tree().call_group("demon_enemy", "on_divine_tier_raised", 6)
		_show_hud_message("✨ DIVINE. You deal double damage. Angel Champion fights at your side. All demons flee.")

func _show_hud_message(msg: String) -> void:
	## Floating world-space text above the player for tier announcements.
	if is_instance_valid(_player) and _player.has_method("_show_float_text"):
		_player._show_float_text(msg, _player.global_position + Vector3(0, 3.5, 0))
