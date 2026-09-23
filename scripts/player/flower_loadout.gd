extends Node
class_name FlowerLoadout

signal slot_changed(slot_index: int, flower_name: String)

const MAX_SLOTS: int = 4

# Each slot holds a flower name string or "" if empty
var slots: Array[String] = ["Rose", "", "", ""]
var active_slot: int = 0


func get_active_flower() -> String:
	return slots[active_slot]


func set_slot(index: int, flower_name: String) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	slots[index] = flower_name
	emit_signal("slot_changed", index, flower_name)


func switch_slot(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	active_slot = index
	emit_signal("slot_changed", active_slot, slots[active_slot])
