extends Node
## VillageManager — autoload that governs the villager unlock system.
## Houses must be repaired before their NPC appears.
## Dead NPCs have their service closed; a replacement arrives the next morning.

signal house_repaired(house_id: String)
signal npc_died(house_id: String)
signal service_opened(house_id: String)
signal service_closed(house_id: String)

## Entrance to Suri Village — replacements spawn here and walk in.
const VILLAGE_ENTRANCE := Vector3(152.0, 2.0, 98.0)

## Name pool for replacement NPCs.
const REPLACEMENT_NAMES := [
	"Brann", "Sera", "Owin", "Lysa", "Cedd", "Faye",
	"Hal", "Wren", "Brom", "Nessa", "Thane", "Isla",
	"Corvin", "Dwyn", "Mael", "Erin", "Tev", "Asha",
]

## NPC scene paths by house_id.
const NPC_SCENES := {
	"cottage_1": "res://scenes/npc/Priest.tscn",
	"cottage_3": "res://scenes/npc/FemaleVillager.tscn",
	"cottage_4": "res://scenes/npc/MaleVillager.tscn",
	"cottage_5": "res://scenes/npc/Kipatah.tscn",
}

## Role label by house_id (for service open/close messages).
const HOUSE_ROLES := {
	"cottage_1": "priest",
	"cottage_3": "shop_keeper",
	"cottage_4": "blacksmith",
	"cottage_5": "kipatah",
}

## { house_id -> { repaired, npc_alive, npc_node } }
var _states: Dictionary = {}

## Houses whose NPC died and need a replacement next morning.
var _pending_replacements: Array = []

## NPCs registered during _ready() before their house was repaired.
var _dormant_npcs: Dictionary = {}   # house_id -> Node

var _dnc: Node = null

func _ready() -> void:
	# Initialise state table for every managed house.
	for hid in NPC_SCENES.keys():
		_states[hid] = { "repaired": false, "npc_alive": false, "npc_node": null }

	# Connect to day/night cycle.
	_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc == null:
		await get_tree().process_frame
		_dnc = get_tree().get_first_node_in_group("day_night")
	if _dnc != null:
		_dnc.day_started.connect(_on_day_started)

# ─────────────────────────────────────────────
#  Public API — called by HouseRepair or NPCs
# ─────────────────────────────────────────────

## Called by HouseRepair when the player completes a repair.
func repair_house(house_id: String) -> void:
	if not _states.has(house_id):
		push_warning("VillageManager: unknown house_id '%s'" % house_id)
		return
	if _states[house_id]["repaired"]:
		return  # already fixed
	_states[house_id]["repaired"] = true
	house_repaired.emit(house_id)

	# If the NPC was dormant (already in the scene but waiting), wake it.
	if _dormant_npcs.has(house_id):
		_activate_dormant(house_id)
	else:
		# Otherwise spawn a fresh instance from the scene file.
		_spawn_npc(house_id)

## Called by an NPC when it dies (from damage system or other cause).
func report_npc_death(house_id: String) -> void:
	if not _states.has(house_id):
		return
	_states[house_id]["npc_alive"] = false
	_states[house_id]["npc_node"] = null
	npc_died.emit(house_id)
	service_closed.emit(house_id)
	# Queue replacement for next morning.
	if house_id not in _pending_replacements:
		_pending_replacements.append(house_id)

## Called by NPC _ready() if its house is not yet repaired.
## Keeps a reference so VillageManager can activate it later instead of spawning a new one.
func register_dormant_npc(house_id: String, npc_node: Node) -> void:
	_dormant_npcs[house_id] = npc_node

## Returns true if the house has been repaired.
func is_repaired(house_id: String) -> bool:
	return _states.get(house_id, {}).get("repaired", false)

## Returns true if the NPC for this house is currently alive.
func is_npc_alive(house_id: String) -> bool:
	return _states.get(house_id, {}).get("npc_alive", false)

# ─────────────────────────────────────────────
#  Internal
# ─────────────────────────────────────────────

func _on_day_started() -> void:
	if _pending_replacements.is_empty():
		return
	# Spawn one replacement per pending house each morning.
	var batch := _pending_replacements.duplicate()
	_pending_replacements.clear()
	for house_id in batch:
		_spawn_replacement(house_id)

func _activate_dormant(house_id: String) -> void:
	var npc: Node = _dormant_npcs[house_id]
	_dormant_npcs.erase(house_id)
	if not is_instance_valid(npc):
		_spawn_npc(house_id)
		return
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	npc.visible = true
	# Position at village entrance and tell the NPC to walk home.
	npc.global_position = VILLAGE_ENTRANCE
	if npc.has_method("begin_walk_in"):
		npc.begin_walk_in()
	_states[house_id]["npc_alive"] = true
	_states[house_id]["npc_node"] = npc
	service_opened.emit(house_id)

func _spawn_npc(house_id: String) -> void:
	if not NPC_SCENES.has(house_id):
		return
	var packed = load(NPC_SCENES[house_id])
	if packed == null:
		push_warning("VillageManager: scene not found for house '%s'" % house_id)
		return
	var npc: Node = packed.instantiate()
	get_tree().current_scene.add_child(npc)
	npc.global_position = VILLAGE_ENTRANCE
	if npc.has_method("begin_walk_in"):
		npc.begin_walk_in()
	_states[house_id]["npc_alive"] = true
	_states[house_id]["npc_node"] = npc
	service_opened.emit(house_id)

func _spawn_replacement(house_id: String) -> void:
	if not NPC_SCENES.has(house_id):
		return
	var packed = load(NPC_SCENES[house_id])
	if packed == null:
		return
	var npc: Node = packed.instantiate()
	# Give them a new random name.
	var new_name: String = REPLACEMENT_NAMES[randi() % REPLACEMENT_NAMES.size()]
	if npc.has_method("set") and "display_name" in npc:
		npc.display_name = new_name
	get_tree().current_scene.add_child(npc)
	npc.global_position = VILLAGE_ENTRANCE
	if npc.has_method("begin_walk_in"):
		npc.begin_walk_in()
	_states[house_id]["npc_alive"] = true
	_states[house_id]["npc_node"] = npc
	service_opened.emit(house_id)
