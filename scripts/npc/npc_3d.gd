extends Node3D

signal interact_requested(npc: Node3D)

var _t: float = 0.0
var player_nearby: bool = false

@onready var _interact_zone: Area3D = $InteractZone


func _ready() -> void:
	_interact_zone.body_entered.connect(_on_interact_zone_body_entered)
	_interact_zone.body_exited.connect(_on_interact_zone_body_exited)


func _process(delta: float) -> void:
	_t += delta
	rotation.y = sin(_t * 0.8) * 0.6

	if not player_nearby:
		return
	if not Input.is_key_pressed(KEY_E):
		return
	var forest_zone: Node = get_tree().current_scene
	if forest_zone.has_method("is_npc_interact_suppressed") and forest_zone.is_npc_interact_suppressed():
		return
	var dialog_layer: CanvasLayer = forest_zone.get_node("DialogLayer")
	if dialog_layer.visible:
		return
	interact_requested.emit(self)


func _on_interact_zone_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_nearby = true


func _on_interact_zone_body_exited(_body: Node3D) -> void:
	player_nearby = false
