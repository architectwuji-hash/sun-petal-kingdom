class_name WeatherAtmosphereParticles3D
extends Node3D

## Camera-following local mist and reusable airborne particles.
## Airborne styles cover dust, ash, and pollen without separate systems.

const MIST_COUNTS := {
	WeatherController3D.Quality.LOW: 12,
	WeatherController3D.Quality.MEDIUM: 24,
	WeatherController3D.Quality.HIGH: 42,
}
const AIRBORNE_COUNTS := {
	WeatherController3D.Quality.LOW: 90,
	WeatherController3D.Quality.MEDIUM: 220,
	WeatherController3D.Quality.HIGH: 600,
}

@export var controller: WeatherController3D
@export var camera: Camera3D
@export_range(2.0, 40.0, 0.5) var follow_radius := 14.0
@export_range(5.0, 120.0, 0.5) var max_camera_distance := 45.0
@export_range(-10.0, 20.0, 0.25) var vertical_offset := 2.5
@export var follow_camera_height := false

var _mist: GPUParticles3D
var _airborne: GPUParticles3D
var _last_state: Dictionary = {}
var _airborne_buoyancy := 0.0
var _airborne_type := WeatherProfile.AirborneType.DUST


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherAtmosphereParticles3D requires a WeatherController3D.")
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
	if camera != null:
		var target := controller.get_effect_anchor_position()
		if not follow_camera_height:
			target.y = 0.0
		global_position = target + Vector3.UP * vertical_offset
	_apply_wind(controller.get_wind_velocity(0.43))


func get_allocated_particle_count() -> int:
	return _mist.amount + _airborne.amount


func _create_emitters() -> void:
	_mist = _create_mist_emitter()
	_airborne = _create_airborne_emitter()
	add_child(_mist)
	add_child(_airborne)


func _create_mist_emitter() -> GPUParticles3D:
	var emitter := _base_emitter("LocalMist")
	emitter.lifetime = 13.0
	emitter.randomness = 0.5
	emitter.preprocess = 4.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(follow_radius, 2.0, follow_radius)
	process.direction = Vector3.RIGHT
	process.spread = 18.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.32
	process.gravity = Vector3.ZERO
	process.scale_min = 0.7
	process.scale_max = 1.4
	process.color = Color.WHITE
	emitter.process_material = process
	emitter.draw_pass_1 = _create_quad(Vector2(8.5, 3.0), Color(0.72, 0.76, 0.82, 0.28), _create_mist_texture())
	return emitter


func _create_airborne_emitter() -> GPUParticles3D:
	var emitter := _base_emitter("AirborneParticles")
	emitter.lifetime = 8.0
	emitter.randomness = 0.6
	emitter.preprocess = 2.5
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(follow_radius, 6.0, follow_radius)
	process.direction = Vector3.RIGHT
	process.spread = 35.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, -0.05, 0.0)
	process.scale_min = 0.45
	process.scale_max = 1.5
	process.angular_velocity_min = -90.0
	process.angular_velocity_max = 90.0
	process.color = Color.WHITE
	emitter.process_material = process
	emitter.draw_pass_1 = _create_quad(Vector2(0.16, 0.16), Color(0.72, 0.58, 0.35, 0.92), _create_speck_texture())
	return emitter


func _base_emitter(node_name: String) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = node_name
	emitter.emitting = false
	emitter.amount_ratio = 0.0
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.local_coords = false
	emitter.fixed_fps = 20
	emitter.interpolate = true
	emitter.fract_delta = true
	emitter.visibility_aabb = AABB(Vector3(-25.0, -16.0, -25.0), Vector3(50.0, 32.0, 50.0))
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	return emitter


func _create_quad(size: Vector2, color: Color, texture: Texture2D) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = false
	material.albedo_color = color
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 1.0
	material.distance_fade_max_distance = maxf(max_camera_distance, 5.0)
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


func _create_mist_texture() -> ImageTexture:
	var width := 128
	var height := 64
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.55
	for y in height:
		for x in width:
			var uv := Vector2((float(x) + 0.5) / width, (float(y) + 0.5) / height)
			var edge_x := 1.0 - smoothstep(0.28, 0.5, absf(uv.x - 0.5))
			var edge_y := 1.0 - smoothstep(0.18, 0.5, absf(uv.y - 0.5))
			var noise_value := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var alpha := edge_x * edge_y * smoothstep(0.18, 0.78, noise_value)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _create_speck_texture() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var uv := Vector2((float(x) + 0.5) / size, (float(y) + 0.5) / size)
			var distance_from_center := uv.distance_to(Vector2(0.5, 0.5)) * 2.0
			var alpha := 1.0 - smoothstep(0.3, 1.0, distance_from_center)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _apply_state(state: Dictionary) -> void:
	if _mist == null:
		return
	_last_state = state.duplicate(true)
	var mist_intensity := clampf(float(state.get("mist_intensity", 0.0)), 0.0, 1.0)
	var airborne_intensity := clampf(float(state.get("airborne_intensity", 0.0)), 0.0, 1.0)
	_set_intensity(_mist, mist_intensity)
	_set_intensity(_airborne, airborne_intensity)
	_airborne_type = int(state.get("airborne_type", WeatherProfile.AirborneType.DUST))
	_airborne_buoyancy = float(state.get("airborne_buoyancy", 0.0))
	var mist_mesh := _mist.draw_pass_1 as QuadMesh
	var mist_material := mist_mesh.material as StandardMaterial3D
	var fog_tint: Color = state.get("fog_color", Color(0.72, 0.76, 0.82))
	mist_material.albedo_color = Color(fog_tint.r, fog_tint.g, fog_tint.b, 0.34)
	_apply_airborne_appearance(state)
	_apply_wind(controller.get_wind_velocity(0.43))


func _apply_airborne_appearance(state: Dictionary) -> void:
	var tint: Color = state.get("precipitation_color", Color.WHITE)
	var size_scale := maxf(float(state.get("airborne_size_scale", 1.0)), 0.1)
	var base_size := Vector2(0.16, 0.16)
	var alpha := 0.92
	match _airborne_type:
		WeatherProfile.AirborneType.ASH:
			base_size = Vector2(0.075, 0.04)
			alpha = 0.65
		WeatherProfile.AirborneType.POLLEN:
			base_size = Vector2(0.035, 0.035)
			alpha = 0.9
	var mesh := _airborne.draw_pass_1 as QuadMesh
	mesh.size = base_size * size_scale
	var material := mesh.material as StandardMaterial3D
	material.albedo_color = Color(tint.r, tint.g, tint.b, tint.a * alpha)


func _apply_wind(wind_velocity: Vector3) -> void:
	if _mist == null:
		return
	var mist_process := _mist.process_material as ParticleProcessMaterial
	var airborne_process := _airborne.process_material as ParticleProcessMaterial
	mist_process.gravity = Vector3(wind_velocity.x * 0.055, 0.0, wind_velocity.z * 0.055)
	var style_gravity := -0.08
	match _airborne_type:
		WeatherProfile.AirborneType.ASH:
			style_gravity = -0.18
		WeatherProfile.AirborneType.POLLEN:
			style_gravity = 0.02
	airborne_process.gravity = Vector3(
		wind_velocity.x * 0.32,
		style_gravity + _airborne_buoyancy,
		wind_velocity.z * 0.32,
	)


func _set_intensity(emitter: GPUParticles3D, intensity: float) -> void:
	var should_emit := intensity > 0.001
	if should_emit and not emitter.emitting:
		emitter.emitting = true
		emitter.restart()
	emitter.amount_ratio = intensity
	if not should_emit:
		emitter.emitting = false


func _on_quality_changed(value: WeatherController3D.Quality) -> void:
	_apply_quality(value)
	if not _last_state.is_empty():
		_apply_state(_last_state)


func _apply_quality(value: WeatherController3D.Quality) -> void:
	if _mist == null:
		return
	_mist.amount = int(MIST_COUNTS.get(value, MIST_COUNTS[WeatherController3D.Quality.HIGH]))
	_airborne.amount = int(AIRBORNE_COUNTS.get(value, AIRBORNE_COUNTS[WeatherController3D.Quality.HIGH]))
