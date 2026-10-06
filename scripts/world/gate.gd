extends Node3D

## Gate — press E to build (costs wood), then open / close to let the player through.
## "Open" means collision disabled so the player can walk through.
## "Closed" means collision active — player is blocked.

const INTERACT_RANGE := 3.5
const WOOD_COST      := 4   ## wood to build the gate (same as fence reinforce)

var _purchased : bool = false
var _open      : bool = false

func _ready() -> void:
	add_to_group("interactable")
	_add_label()

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "[E] Build Gate (" + str(WOOD_COST) + " Wood)"
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
			if not _purchased:
				lbl.text = "[E] Build Gate (" + str(WOOD_COST) + " Wood)"
			elif _open:
				lbl.text = "[E] Close Gate"
			else:
				lbl.text = "[E] Open Gate"

func interact(player: Node) -> void:
	if not _purchased:
		_try_purchase(player)
	else:
		_toggle(player)

## Spend wood to unlock the gate.
func _try_purchase(player: Node) -> void:
	var has_wood_method := player.has_method("get_item_count")
	var wood_count: int = player.get_item_count("wood") if has_wood_method else WOOD_COST
	if wood_count >= WOOD_COST:
		if player.has_method("remove_item"):
			player.remove_item("wood", WOOD_COST)
		_purchased = true
		# Gate starts closed — keep collision enabled.
		_set_collision_enabled(true)
		_float_msg(player, "Gate built!  (-" + str(WOOD_COST) + " Wood)")
	else:
		_float_msg(player, "Need " + str(WOOD_COST) + " Wood  (have " + str(wood_count) + ")")

## Toggle open / closed (collision only — no animation).
func _toggle(_player: Node) -> void:
	_open = not _open
	_set_collision_enabled(not _open)

## Walk the tree and disable / enable every CollisionShape3D found.
func _set_collision_enabled(enable: bool) -> void:
	_walk(self, enable)

func _walk(node: Node, enable: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enable
	for child: Node in node.get_children():
		_walk(child, enable)

func _float_msg(player: Node, text: String) -> void:
	if player.has_method("_show_float_text"):
		player._show_float_text(text, global_position + Vector3(0, 2.5, 0))
