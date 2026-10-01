class_name WeatherWindVisualizer3D
extends Node3D

## Optional runtime wind arrow for tuning profiles and integrations.
## Disabled by default and intentionally excluded from normal presentation.

@export var controller: WeatherController3D
@export var camera: Camera3D
@export var enabled := false
@export_range(0.5, 10.0, 0.1) var distance_from_camera := 3.5
@export_range(-5.0, 10.0, 0.1) var height_offset := 0.4
@export_range(1.0, 80.0, 0.5) var display_speed_max := 25.0

var _arrow: Node3D
var _material: StandardMaterial3D


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherWindVisualizer3D requires a WeatherController3D.")
		set_process(false)
		return
	if camera == null:
		camera = controller.camera
	_create_arrow()
	set_enabled(enabled)


func _process(_delta: float) -> void:
	if not enabled:
		return
	if controller.camera != null and camera != controller.camera:
		camera = controller.camera
	if camera == null:
		visible = false
		return
	var wind := controller.get_wind_velocity(0.19)
	var speed := wind.length()
	if speed <= 0.01:
		visible = false
		return
	visible = true
	var direction := wind / speed
	global_position = camera.global_position + (-camera.global_transform.basis.z * distance_from_camera) + Vector3.UP * height_offset
	look_at(global_position + direction, Vector3.UP)
	var length_scale := lerpf(0.45, 2.8, clampf(speed / display_speed_max, 0.0, 1.0))
	_arrow.scale = Vector3(1.0, 1.0, length_scale)
	var pulse := sin(Time.get_ticks_msec() * 0.006) * 0.08 + 0.92
	_material.albedo_color = Color(0.25, 0.9, 1.0, pulse)


func set_enabled(value: bool) -> void:
	enabled = value
	visible = enabled


func is_enabled() -> bool:
	return enabled


func _create_arrow() -> void:
	_arrow = Node3D.new()
	_arrow.name = "Arrow"
	add_child(_arrow)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.25, 0.9, 1.0, 0.92)
	_material.emission_enabled = true
	_material.emission = Color(0.15, 0.72, 0.92)
	_material.emission_energy_multiplier = 1.8

	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.07, 0.07, 1.15)
	shaft_mesh.material = _material
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = shaft_mesh
	shaft.position.z = -0.58
	_arrow.add_child(shaft)

	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.2
	head_mesh.height = 0.46
	head_mesh.radial_segments = 10
	head_mesh.material = _material
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.z = -1.32
	head.rotation_degrees.x = -90.0
	_arrow.add_child(head)
