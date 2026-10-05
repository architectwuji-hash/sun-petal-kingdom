extends Node3D

## Gate — must be purchased with Wood, then opens/closes with E.
## Attach to the root node of your imported gate model.

const WOOD_COST      := 8
const INTERACT_RANGE := 3.5
const SWING_DEGREES  := 90.0
const SWING_DURATION := 0.45

var purchased  : bool = false
var _open      := false
var _animating := false
var _player_ref: Node = null
var _tween     : Tween = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("purchasable_fence")
	_add_label()
	_apply_visual_state()

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text      = "[E] Buy Gate  (%d Wood)" % WOOD_COST
	lbl.position  = Vector3(0, 2.2, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate  = Color(1.0, 0.85, 0.2)
	lbl.visible   = false
	lbl.name      = "InteractLabel"
	add_child(lbl)

func _physics_process(_delta: float) -> void:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")

	var lbl: Label3D = get_node_or_null("InteractLabel")
	if _player_ref == null:
		if lbl: lbl.visible = false
		return

	var dist: float = global_position.distance_to(_player_ref.global_position)

	if lbl:
		lbl.visible = dist < INTERACT_RANGE + 1.5
		if lbl.visible:
			if not purchased:
				lbl.text = "[E] Buy Gate  (%d Wood)" % WOOD_COST
			else:
				lbl.text = "[E] Close" if _open else "[E] Open"

func interact(player: Node) -> void:
	if not purchased:
		_try_purchase(player)
	else:
		if not _animating:
			_toggle()

func _try_purchase(player: Node) -> void:
	if not player.has_method("get_item_count"):
		return
	if player.get_item_count("wood") >= WOOD_COST:
		player.remove_item("wood", WOOD_COST)
		purchased = true
		_apply_visual_state()
		_spawn_float_label(player, "Gate unlocked!  (-%d Wood)" % WOOD_COST, Color(0.4, 1.0, 0.5))
	else:
		_spawn_float_label(player, "Need %d Wood" % WOOD_COST, Color(1.0, 0.4, 0.3))

func _apply_visual_state() -> void:
	var alpha: float = 1.0 if purchased else 0.35
	_set_alpha_recursive(self, alpha)

func _set_alpha_recursive(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for surf in range(mi.get_surface_override_material_count()):
			var mat: Material = mi.get_active_material(surf)
			if mat:
				var m: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				if m:
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.albedo_color.a = alpha
					mi.set_surface_override_material(surf, m)
		# If no surface overrides, fall back to mesh material slot 0
		if mi.get_surface_override_material_count() == 0:
			var mat: Material = mi.get_active_material(0)
			if mat:
				var m: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				if m:
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.albedo_color.a = alpha
					mi.set_surface_override_material(0, m)
	for child: Node in node.get_children():
		_set_alpha_recursive(child, alpha)

func _toggle() -> void:
	_animating = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var target_y: float = SWING_DEGREES if not _open else 0.0
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "rotation_degrees:y", target_y, SWING_DURATION)
	_tween.finished.connect(func():
		_open = not _open
		_animating = false
	)

func _spawn_float_label(_player: Node, msg: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text      = msg
	lbl.modulate  = col
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector3(0, 2.5, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.2, 0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.tween_callback(lbl.queue_free).set_delay(1.2)
