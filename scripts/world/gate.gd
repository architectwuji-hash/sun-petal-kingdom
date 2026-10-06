extends Node3D

## Gate -- press E to toggle open / closed.
## Open: gate mesh hidden, collision disabled.
## Closed: gate mesh visible, collision active.

const INTERACT_RANGE := 3.5

var _open : bool = false

func _ready() -> void:
	add_to_group("interactable")
	_add_label()

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "[E] Open Gate"
	lbl.position = Vector3(0, 2.2, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.85, 0.2)
	lbl.visible = false
	lbl.name = "InteractLabel"
	add_child(lbl)

func _physics_process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var lbl: Label3D = get_node_or_null("InteractLabel")
	if player == null:
		if lbl:
			lbl.visible = false
		return
	var dist: float = global_position.distance_to(player.global_position)
	if lbl:
		lbl.visible = dist < INTERACT_RANGE + 1.5
		if lbl.visible:
			lbl.text = "[E] Close Gate" if _open else "[E] Open Gate"

func interact(_player: Node) -> void:
	_open = not _open
	_set_collision_enabled(not _open)

## Walk the tree and disable / enable every CollisionShape3D we find.
func _set_collision_enabled(enable: bool) -> void:
	_walk(self, enable)

func _walk(node: Node, enable: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enable
	for child: Node in node.get_children():
		_walk(child, enable)
