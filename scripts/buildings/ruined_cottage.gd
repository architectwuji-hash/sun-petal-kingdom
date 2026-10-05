extends Node3D
class_name RuinedCottage
## RuinedCottage — press E near it to spend wood+stone and restore it.
## The restored version can take damage from enemies and revert back.
##
## Attach this script directly to any ruined_stone_cottage_3d_model instance.

const REPAIR_WOOD  := 10   ## wood planks required
const REPAIR_STONE := 8    ## stone blocks required
const COTTAGE_MAX_HP := 120  ## restored cottage health before it's ruined again

const FIXED_SCENE := preload("res://TripoModels/stone_cottage_3d_model/stone_cottage_3d_model.fbx")

var _repaired:   bool     = false
var _fixed_node: Node3D   = null   ## the live stone cottage instance
var _prompt_label: Label3D = null

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ruined_cottage")
	_build_prompt_label()

func _build_prompt_label() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.name         = "RepairPrompt"
	_prompt_label.text         = "[E] Repair  %d🪵 + %d🪨" % [REPAIR_WOOD, REPAIR_STONE]
	_prompt_label.pixel_size   = 0.06
	_prompt_label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.font_size    = 48
	_prompt_label.outline_size = 6
	_prompt_label.modulate     = Color(1.0, 0.9, 0.4, 1.0)
	_prompt_label.position     = Vector3(0, 8, 0)
	_prompt_label.visible      = false
	add_child(_prompt_label)

# ── Proximity prompt ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _repaired or _prompt_label == null:
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_prompt_label.visible = false
		return
	var dist: float = global_position.distance_to((players[0] as Node3D).global_position)
	_prompt_label.visible = dist < 12.0

# ── E-key interaction: repair the ruin ───────────────────────────────────────

func interact(player: Node3D) -> void:
	if _repaired:
		return
	var wood_have  := player.call("get_item_count", "wood")  as int
	var stone_have := player.call("get_item_count", "stone") as int

	if wood_have < REPAIR_WOOD or stone_have < REPAIR_STONE:
		var msg := "Need %d🪵 + %d🪨  (have %d🪵 %d🪨)" \
			% [REPAIR_WOOD, REPAIR_STONE, wood_have, stone_have]
		player.call("_show_float_text", msg, global_position + Vector3(0, 6, 0))
		return

	player.call("remove_item", "wood",  REPAIR_WOOD)
	player.call("remove_item", "stone", REPAIR_STONE)
	_do_repair()
	player.call("_show_float_text", "🏠 Cottage Restored!", global_position + Vector3(0, 6, 0))
	print("[RuinedCottage] %s repaired!" % name)

# ── Repair helpers ────────────────────────────────────────────────────────────

func _do_repair() -> void:
	_fixed_node = FIXED_SCENE.instantiate() as Node3D
	_fixed_node.name = name + "_restored"
	get_parent().add_child(_fixed_node)
	_fixed_node.global_transform = global_transform
	## Store a damage callable so anything (enemy, explosion, etc.) can call:
	##   node.get_meta("_damage_callable").call(amount)
	_fixed_node.set_meta("_damage_callable", Callable(self, "take_damage"))
	_fixed_node.set_meta("hp",     COTTAGE_MAX_HP)
	_fixed_node.set_meta("max_hp", COTTAGE_MAX_HP)
	_fixed_node.add_to_group("damageable_building")
	_repaired = true
	visible   = false
	remove_from_group("interactable")
	if _prompt_label:
		_prompt_label.queue_free()
		_prompt_label = null

func _do_repair_silently() -> void:
	## Used by the save system — no resource cost.
	_do_repair()

# ── Damage (received by the restored cottage) ─────────────────────────────────

func take_damage(amount: int) -> void:
	if not _repaired or _fixed_node == null:
		return
	var hp: int = _fixed_node.get_meta("hp", COTTAGE_MAX_HP) as int
	hp -= amount
	_fixed_node.set_meta("hp", hp)
	print("[RuinedCottage] %s hp → %d" % [name, hp])
	if hp <= 0:
		_revert_to_ruined()

func _revert_to_ruined() -> void:
	if _fixed_node:
		_fixed_node.queue_free()
		_fixed_node = null
	visible   = true
	_repaired = false
	add_to_group("interactable")
	_build_prompt_label()
	print("[RuinedCottage] %s reverted to ruined!" % name)

# ── Save / Load ───────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	var hp: int = COTTAGE_MAX_HP
	if _fixed_node and _fixed_node.has_meta("hp"):
		hp = _fixed_node.get_meta("hp") as int
	return {
		"node_name": name,
		"repaired":  _repaired,
		"hp":        hp,
	}

func apply_save_data(d: Dictionary) -> void:
	if d.get("repaired", false):
		_do_repair_silently()
		if _fixed_node:
			_fixed_node.set_meta("hp", d.get("hp", COTTAGE_MAX_HP))
