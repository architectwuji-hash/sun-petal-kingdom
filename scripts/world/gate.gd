extends Node3D

## Gate — press E to toggle open / closed.
## Closed: collision active, nothing can pass.
## Open:   collision disabled, walk right through.

const INTERACT_RANGE  := 3.5
const SWING_DEGREES   := 90.0
const SWING_DURATION  := 0.4

var _open      : bool = false
var _animating : bool = false
var _tween     : Tween = null

func _ready() -> void:
	add_to_group("interactable")
	_add_label()

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text      = "[E] Open Gate"
	lbl.position  = Vector3(0, 2.2, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate  = Color(1.0, 0.85, 0.2)
	lbl.visible   = false
	lbl.name      = "InteractLabel"
	add_child(lbl)

func _physics_process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var lbl: Label3D = get_node_or_null("InteractLabel")
	if player == null:
		if lbl: lbl.visible = false
		return
	var dist: float = global_position.distance_to(player.global_position)
	if lbl:
		lbl.visible = dist < INTERACT_RANGE + 1.5
		if lbl.visible:
			lbl.text = "[E] Close Gate" if _open else "[E] Open Gate"

func interact(_player: Node) -> void:
	if not _animating:
		_toggle()

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
		_set_collision_enabled(not _open)
	)

## Walk the tree and disable / enable every CollisionShape3D we find.
func _set_collision_enabled(enable: bool) -> void:
	_walk(self, enable)

func _walk(node: Node, enable: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enable
	for child: Node in node.get_children():
		_walk(child, enable)
