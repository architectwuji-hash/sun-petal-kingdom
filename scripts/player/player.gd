extends CharacterBody3D
class_name Player

signal ocali_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal level_changed(new_level: int, xp: int, xp_required: int)
signal died

@export var move_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.003
@export var max_ocali: int = 750
@export var respawn_delay: float = 3.0

const GRAVITY: float = 20.0

## Tree running — triple jump to reach canopy platforms
const JUMP_COUNT_MAX : int   = 3
var _jumps_remaining : int   = 0
var _tree_running    : Node  = null   ## TreeRunning component (added in _ready)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera
@onready var attack_controller: AttackController = $AttackController
@onready var ocali_regen: OcaliRegen = $OcaliRegen
@onready var flower_loadout: FlowerLoadout = $FlowerLoadout
@onready var power_handler: PowerHandler = $PowerHandler

var level: int = 1
var xp: int = 0
var max_health: int = 100
var health: int = 100
var ocali: int = 750
var _camera_pitch: float = 0.0
var _is_dead: bool = false
var inventory: Dictionary = {"meat": 0, "cowhide": 0, "souls": 0, "monkey_fur": 0, "wood": 0}


func _get_xp_required() -> int:
	return level * level * 5


func _get_max_health_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 50


func _ready() -> void:
	add_to_group("player")
	# Tree running setup (Tier 3 for testing — gives 3s timer and 2 trees shown)
	var tr_script : GDScript = load("res://scripts/player/tree_running.gd")
	if tr_script:
		_tree_running = tr_script.new()
		_tree_running.name = "TreeRunning"
		_tree_running.tier = 3
		add_child(_tree_running)
	max_health = _get_max_health_for_level(level)
	health = max_health
	ocali = max_ocali
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	attack_controller.init(self)
	ocali_regen.init(self)
	power_handler.init(self, flower_loadout)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.4)
		camera_pivot.rotation.x = _camera_pitch
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("melee_attack"):
		attack_controller.try_melee_attack(camera)
	if event.is_action_pressed("use_power"):
		power_handler.use_power()
	if event.is_action_pressed("slot_1"):
		flower_loadout.switch_slot(0)
	if event.is_action_pressed("slot_2"):
		flower_loadout.switch_slot(1)
	if event.is_action_pressed("slot_3"):
		flower_loadout.switch_slot(2)
	if event.is_action_pressed("slot_4"):
		flower_loadout.switch_slot(3)
	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if is_on_floor():
		_jumps_remaining = JUMP_COUNT_MAX   ## reset charges on landing
	else:
		velocity.y -= GRAVITY * delta

	# Triple jump — 3 charges so the player can reach tree canopy platforms
	if Input.is_action_just_pressed("ui_accept"):
		# While in tree-running CHOOSING state, Space selects a tree (handled by tree_running.gd)
		var in_tree_run : bool = _tree_running != null and _tree_running.is_tree_running()
		if not in_tree_run and _jumps_remaining > 0:
			velocity.y = jump_velocity
			_jumps_remaining -= 1
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else move_speed
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir == Vector2.ZERO:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()


func add_xp(amount: int) -> void:
	xp += amount
	var required: int = _get_xp_required()
	while xp >= required:
		xp -= required
		level += 1
		max_health = _get_max_health_for_level(level)
		health = max_health
		ocali = max_ocali
		emit_signal("health_changed", health, max_health)
		emit_signal("ocali_changed", ocali, max_ocali)
		_level_up_flash()
		required = _get_xp_required()
	emit_signal("level_changed", level, xp, required)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	health = clampi(health - amount, 0, max_health)
	emit_signal("health_changed", health, max_health)
	if health <= 0:
		_die()


func spend_ocali(amount: int) -> bool:
	if ocali < amount:
		return false
	ocali -= amount
	emit_signal("ocali_changed", ocali, max_ocali)
	return true


func restore_ocali(amount: int) -> void:
	ocali = clampi(ocali + amount, 0, max_ocali)
	emit_signal("ocali_changed", ocali, max_ocali)


func _die() -> void:
	_is_dead = true
	emit_signal("died")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	health = max_health
	ocali = max_ocali
	_is_dead = false
	global_position = Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	emit_signal("health_changed", health, max_health)
	emit_signal("ocali_changed", ocali, max_ocali)
	emit_signal("level_changed", level, xp, _get_xp_required())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func add_item(item: String) -> void:
	if inventory.has(item):
		inventory[item] += 1
	else:
		inventory[item] = 1
	print("Picked up: ", item, " (", inventory[item], ")")

func get_item_count(item: String) -> int:
	return int(inventory.get(item, 0))

func remove_item(item: String, amount: int = 1) -> void:
	if inventory.has(item):
		inventory[item] = maxi(0, inventory[item] - amount)

func drown() -> void:
	health = clampi(health - 50, 0, max_health)
	emit_signal("health_changed", health, max_health)
	global_position = Vector3(-80, 0, 74)
	velocity = Vector3.ZERO
	print("You drowned! Respawned.")

# ── Soul Absorption & Level-Up Visuals ───────────────────────────────────────

## Called by EnemyBase._absorb_into_player() once the orb reaches the player.
func absorb_soul() -> void:
	_screen_flash(Color(0.3, 0.9, 1.0, 0.35), 0.12, 0.3)


## Golden screen flash to celebrate a level-up.
func _level_up_flash() -> void:
	_screen_flash(Color(1.0, 0.85, 0.1, 0.65), 0.15, 0.7)
	_spawn_level_up_label()


## Creates a full-screen transparent ColorRect, briefly tints it, then fades it.
func _screen_flash(color: Color, hold: float, fade: float) -> void:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().add_child(overlay)
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(overlay, "color", Color(color.r, color.g, color.b, 0.0), fade)
	tw.tween_callback(overlay.queue_free)


## Floating "Level Up!" label that rises and fades above the player.
func _spawn_level_up_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "Level Up! ✦ Lv." + str(level)
	lbl.modulate = Color(1.0, 0.9, 0.1)
	lbl.font_size = 72
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, 2.5, 0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.8, 0), 1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.4).set_delay(0.3)
	tw.tween_callback(lbl.queue_free).set_delay(1.4)


# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	var saved_slots: Array[String] = []
	for s: String in flower_loadout.slots:
		saved_slots.append(s)
	return {
		"class":               "Player",
		"x":                   global_position.x,
		"y":                   global_position.y,
		"z":                   global_position.z,
		"rot_y":               rotation.y,
		"health":              health,
		"ocali":               ocali,
		"level":               level,
		"xp":                  xp,
		"inventory":           inventory.duplicate(),
		"flower_slots":        saved_slots,
		"flower_active_slot":  flower_loadout.active_slot,
	}


func apply_save_data(d: Dictionary) -> void:
	global_position = Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 1.0)),
		float(d.get("z", 0.0))
	)
	rotation.y = float(d.get("rot_y", 0.0))
	level      = int(d.get("level", 1))
	xp         = int(d.get("xp", 0))
	max_health = _get_max_health_for_level(level)
	health     = clampi(int(d.get("health", max_health)), 0, max_health)
	ocali      = clampi(int(d.get("ocali", max_ocali)),   0, max_ocali)
	# Restore inventory
	var saved_inv: Dictionary = d.get("inventory", {})
	for key: String in saved_inv:
		inventory[key] = int(saved_inv[key])
	# Restore flower loadout
	var saved_slots: Array = d.get("flower_slots", ["Rose", "", "", ""])
	for i: int in range(mini(saved_slots.size(), FlowerLoadout.MAX_SLOTS)):
		flower_loadout.set_slot(i, str(saved_slots[i]))
	flower_loadout.switch_slot(int(d.get("flower_active_slot", 0)))
	# Fire signals so HUD refreshes
	emit_signal("health_changed",  health, max_health)
	emit_signal("ocali_changed",   ocali,  max_ocali)
	emit_signal("level_changed",   level,  xp, _get_xp_required())


# ── Interaction System ────────────────────────────────────────────────────────

const INTERACT_RANGE := 4.0   ## metres — must find something within this radius

## Finds the closest node in the "interactable" group within INTERACT_RANGE.
func _find_nearest_interactable() -> Node:
	var best: Node = null
	var best_dist: float = INTERACT_RANGE
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node):
			continue
		var n3d := node as Node3D
		if n3d == null:
			continue
		var d: float = global_position.distance_to(n3d.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


## Called when E is pressed — finds the nearest interactable and fires interact().
func _try_interact() -> void:
	var target: Node = _find_nearest_interactable()
	if target != null and target.has_method("interact"):
		target.interact(self)


## Floating feedback text shown above a world position (called by gate.gd etc.)
func _show_float_text(text: String, world_pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 36
	lbl.modulate = Color(1.0, 0.9, 0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = world_pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", world_pos + Vector3(0, 1.5, 0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.2)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)
