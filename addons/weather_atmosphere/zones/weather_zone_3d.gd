class_name WeatherZone3D
extends Area3D

## Requests a weather profile while at least one matching body is inside.

@export var profile: WeatherProfile
@export var controller: WeatherController3D
@export var target_group: StringName = &"weather_target"
@export var weather_priority := 0
@export_range(0.0, 30.0, 0.1) var enter_transition_duration := 1.0
@export_range(0.0, 30.0, 0.1) var exit_transition_duration := 1.0

var _matching_bodies: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if controller == null:
		controller = _find_controller()


func _exit_tree() -> void:
	if controller != null:
		controller.release_zone(self, true, exit_transition_duration)


func _on_body_entered(body: Node3D) -> void:
	if not target_group.is_empty() and not body.is_in_group(target_group):
		return
	_matching_bodies[body.get_instance_id()] = body
	if _matching_bodies.size() == 1 and controller != null and profile != null:
		controller.request_zone(self, profile, weather_priority, enter_transition_duration)


func _on_body_exited(body: Node3D) -> void:
	_matching_bodies.erase(body.get_instance_id())
	if _matching_bodies.is_empty() and controller != null:
		controller.release_zone(self, true, exit_transition_duration)


func _find_controller() -> WeatherController3D:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"weather_controller") as WeatherController3D
