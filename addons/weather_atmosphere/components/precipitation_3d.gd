class_name WeatherPrecipitation3D
extends Node3D

## Layered rain and snow emitters that follow the active camera.
## Intensity changes use amount_ratio for smooth transitions; quality changes
## alter the real particle allocation so lower tiers reduce GPU workload.

const RAIN_COUNTS := {
	WeatherController3D.Quality.LOW: Vector2i(350, 220),
	WeatherController3D.Quality.MEDIUM: Vector2i(800, 520),
	WeatherController3D.Quality.HIGH: Vector2i(1500, 950),
}
const SNOW_COUNTS := {
	WeatherController3D.Quality.LOW: Vector2i(180, 120),
	WeatherController3D.Quality.MEDIUM: Vector2i(420, 280),
	WeatherController3D.Quality.HIGH: Vector2i(800, 520),
}

@export var controller: WeatherController3D
@export var camera: Camera3D
@export_range(2.0, 30.0, 0.5) var emitter_height := 9.0
@export var follow_camera_height := false

var _rain_near: GPUParticles3D
var _rain_far: GPUParticles3D
var _snow_near: GPUParticles3D
var _snow_far: GPUParticles3D
var _last_state: Dictionary = {}
var _fall_speed_scale := 1.0


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherPrecipitation3D requires a WeatherController3D.")
		set_process(false)
		return
	if camera == null:
		camera = controller.camera
	_create_emitters()
	controller.state_changed.connect(_apply_state)
	controller.quality_changed.connect(_on_quality_changed)
	_apply_quality(controller.quality)
	_apply_state(controller.get_effective_state())


func _process(_delta: float) -> void:
	if controller.camera != null and camera != controller.camera:
		camera = controller.camera
	if camera == null:
		return
	var target_position := controller.get_effect_anchor_position()
	if not follow_camera_height:
		target_position.y = 0.0
	global_position = target_position + Vector3.UP * emitter_height
	_apply_wind_velocity(controller.get_wind_velocity())


func get_allocated_particle_count() -> int:
	return _rain_near.amount + _rain_far.amount + _snow_near.amount + _snow_far.amount


func _create_emitters() -> void:
	_rain_near = _create_rain_emitter("RainNear", true)
	_rain_far = _create_rain_emitter("RainFar", false)
	_snow_near = _create_snow_emitter("SnowNear", true)
	_snow_far = _create_snow_emitter("SnowFar", false)
	for emitter: GPUParticles3D in [_rain_near, _rain_far, _snow_near, _snow_far]:
		add_child(emitter)


func _create_rain_emitter(node_name: String, near_layer: bool) -> GPUParticles3D:
	var emitter := _base_emitter(node_name)
	emitter.lifetime = 1.35 if near_layer else 1.6
	emitter.preprocess = 0.65
	emitter.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(8.0, 1.0, 8.0) if near_layer else Vector3(15.0, 2.0, 15.0)
	process.direction = Vector3.DOWN
	process.spread = 4.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 6.0
	process.gravity = Vector3(0.0, -18.0, 0.0)
	process.color = Color(0.72, 0.82, 0.92, 0.52 if near_layer else 0.24)
	emitter.process_material = process
	emitter.draw_pass_1 = _create_billboard_quad(
		Vector2(0.024, 0.68) if near_layer else Vector2(0.014, 0.4),
		process.color,
		false,
	)
	return emitter


func _create_snow_emitter(node_name: String, near_layer: bool) -> GPUParticles3D:
	var emitter := _base_emitter(node_name)
	emitter.lifetime = 5.5 if near_layer else 7.0
	emitter.randomness = 0.35
	emitter.preprocess = 1.5
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(6.0, 1.5, 6.0) if near_layer else Vector3(12.0, 2.5, 12.0)
	process.direction = Vector3.DOWN
	process.spread = 25.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0.0, -0.8, 0.0)
	process.scale_min = 0.55
	process.scale_max = 1.35
	process.angular_velocity_min = -80.0
	process.angular_velocity_max = 80.0
	process.color = Color(0.92, 0.96, 1.0, 0.92 if near_layer else 0.55)
	emitter.process_material = process
	emitter.draw_pass_1 = _create_billboard_quad(
		Vector2(0.145, 0.145) if near_layer else Vector2(0.085, 0.085),
		process.color,
		true,
	)
	return emitter


func _base_emitter(node_name: String) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = node_name
	emitter.emitting = false
	emitter.amount_ratio = 0.0
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.local_coords = false
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.fract_delta = true
	emitter.visibility_aabb = AABB(Vector3(-20.0, -18.0, -20.0), Vector3(40.0, 36.0, 40.0))
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	return emitter


func _create_billboard_quad(size: Vector2, color: Color, round_particle: bool) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if round_particle else BaseMaterial3D.BILLBOARD_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = _create_particle_texture(round_particle)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


func _create_particle_texture(round_particle: bool) -> ImageTexture:
	var width := 32
	var height := 32 if round_particle else 128
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var uv := Vector2((float(x) + 0.5) / width, (float(y) + 0.5) / height)
			var alpha: float
			if round_particle:
				var distance_from_center := uv.distance_to(Vector2(0.5, 0.5)) * 2.0
				alpha = 1.0 - smoothstep(0.55, 1.0, distance_from_center)
			else:
				var horizontal := 1.0 - smoothstep(0.15, 0.5, absf(uv.x - 0.5))
				var vertical := smoothstep(0.0, 0.12, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y))
				alpha = horizontal * vertical
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _apply_state(state: Dictionary) -> void:
	if _rain_near == null:
		return
	_last_state = state.duplicate(true)
	var rain_intensity := clampf(float(state.get("rain_intensity", 0.0)), 0.0, 1.0)
	var snow_intensity := clampf(float(state.get("snow_intensity", 0.0)), 0.0, 1.0)
	_set_layer_intensity(_rain_near, rain_intensity)
	_set_layer_intensity(_rain_far, rain_intensity * 0.82)
	_set_layer_intensity(_snow_near, snow_intensity)
	_set_layer_intensity(_snow_far, snow_intensity * 0.78)

	_fall_speed_scale = maxf(float(state.get("fall_speed_scale", 1.0)), 0.1)
	_apply_wind_velocity(controller.get_wind_velocity())

	var tint: Color = state.get("precipitation_color", Color.WHITE)
	var size_scale := maxf(float(state.get("particle_size_scale", 1.0)), 0.1)
	_update_mesh(_rain_near, Vector2(0.024, 0.68) * size_scale, tint, 0.52)
	_update_mesh(_rain_far, Vector2(0.014, 0.4) * size_scale, tint, 0.24)
	_update_mesh(_snow_near, Vector2(0.145, 0.145) * size_scale, tint, 0.92)
	_update_mesh(_snow_far, Vector2(0.085, 0.085) * size_scale, tint, 0.62)


func _apply_wind_velocity(wind_velocity: Vector3) -> void:
	if _rain_near == null:
		return
	var rain_gravity := Vector3(wind_velocity.x * 1.8, -18.0 * _fall_speed_scale, wind_velocity.z * 1.8)
	var snow_gravity := Vector3(wind_velocity.x * 0.42, -0.8 * _fall_speed_scale, wind_velocity.z * 0.42)
	(_rain_near.process_material as ParticleProcessMaterial).gravity = rain_gravity
	(_rain_far.process_material as ParticleProcessMaterial).gravity = rain_gravity * 0.88
	(_snow_near.process_material as ParticleProcessMaterial).gravity = snow_gravity
	(_snow_far.process_material as ParticleProcessMaterial).gravity = snow_gravity * 0.82


func _set_layer_intensity(emitter: GPUParticles3D, intensity: float) -> void:
	var should_emit := intensity > 0.001
	if should_emit and not emitter.emitting:
		emitter.emitting = true
		emitter.restart()
	emitter.amount_ratio = intensity
	if not should_emit:
		emitter.emitting = false


func _update_mesh(emitter: GPUParticles3D, size: Vector2, tint: Color, alpha: float) -> void:
	var mesh := emitter.draw_pass_1 as QuadMesh
	if mesh == null:
		return
	mesh.size = size
	var material := mesh.material as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(tint.r, tint.g, tint.b, tint.a * alpha)


func _on_quality_changed(value: WeatherController3D.Quality) -> void:
	_apply_quality(value)
	if not _last_state.is_empty():
		_apply_state(_last_state)


func _apply_quality(value: WeatherController3D.Quality) -> void:
	if _rain_near == null:
		return
	var rain_counts: Vector2i = RAIN_COUNTS.get(value, RAIN_COUNTS[WeatherController3D.Quality.HIGH])
	var snow_counts: Vector2i = SNOW_COUNTS.get(value, SNOW_COUNTS[WeatherController3D.Quality.HIGH])
	_rain_near.amount = rain_counts.x
	_rain_far.amount = rain_counts.y
	_snow_near.amount = snow_counts.x
	_snow_far.amount = snow_counts.y
