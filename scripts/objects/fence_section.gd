## fence_section.gd — Wood-cost fence with Repair / Reinforce / Upgrade
## Attach to a StaticBody3D node.  All interactions happen via player pressing E.
extends StaticBody3D
class_name FenceSection

# ─── wood costs ──────────────────────────────────────────────────────────────
const WOOD_REPAIR    := 2   ## fix a damaged fence back to full
const WOOD_REINFORCE := 4   ## upgrade health cap to 200
const WOOD_UPGRADE   := 5   ## upgrade health cap to 400

# ─── state ────────────────────────────────────────────────────────────────────
enum FenceState { HEALTHY, DAMAGED, REINFORCED, UPGRADED }

var fence_state : FenceState = FenceState.HEALTHY
var max_health  : int = 100
var health      : int = max_health

# cached visuals
var _models : Array[Node3D] = []

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fence")
	# collect any MeshInstance3D children for tinting
	for child in get_children():
		if child is Node3D:
			_models.append(child)

# ─── damage ───────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	health -= amount
	health = clampi(health, 0, max_health)
	if health <= 0:
		queue_free()
		return
	if float(health) / float(max_health) < 0.5 and fence_state == FenceState.HEALTHY:
		fence_state = FenceState.DAMAGED
		_flash_color(Color(0.9, 0.5, 0.2))

# ─── interaction (E key) ──────────────────────────────────────────────────────
func interact(player: Node) -> void:
	if not player.has_method("remove_item"):
		return

	match fence_state:
		FenceState.DAMAGED:
			_try_action(player, "Repair",    WOOD_REPAIR,    _do_repair)
		FenceState.HEALTHY:
			_try_action(player, "Reinforce", WOOD_REINFORCE, _do_reinforce)
		FenceState.REINFORCED:
			_try_action(player, "Upgrade",   WOOD_UPGRADE,   _do_upgrade)
		FenceState.UPGRADED:
			_float_msg(player, "Fence fully upgraded!")

func _try_action(player: Node, label: String, cost: int, callback: Callable) -> void:
	if player.get_item_count("wood") >= cost:
		player.remove_item("wood", cost)
		callback.call()
		_float_msg(player, label + " done!  (-" + str(cost) + " Wood)")
	else:
		_float_msg(player, "Need " + str(cost) + " Wood to " + label
			+ "  (have " + str(player.get_item_count("wood")) + ")")

func _do_repair() -> void:
	health = max_health
	fence_state = FenceState.HEALTHY
	_flash_color(Color(0.4, 1.0, 0.4))

func _do_reinforce() -> void:
	max_health = 200
	health     = max_health
	fence_state = FenceState.REINFORCED
	_flash_color(Color(0.4, 0.7, 1.0))

func _do_upgrade() -> void:
	max_health = 400
	health     = max_health
	fence_state = FenceState.UPGRADED
	_flash_color(Color(1.0, 0.9, 0.2))

# ─── helpers ──────────────────────────────────────────────────────────────────
func _float_msg(player: Node, text: String) -> void:
	if player.has_method("_show_float_text"):
		player._show_float_text(text, global_position + Vector3(0, 2.2, 0))

func _flash_color(col: Color) -> void:
	# Brief colour flash so the player sees the change
	for m in _models:
		if m is MeshInstance3D:
			var orig := m.get_instance_shader_parameter("albedo_tint")
			m.set_instance_shader_parameter("albedo_tint", col)
			var tw := create_tween()
			tw.tween_interval(0.4)
			tw.tween_callback(func():
				m.set_instance_shader_parameter("albedo_tint", Color(1,1,1)))
