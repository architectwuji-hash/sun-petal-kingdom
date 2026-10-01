class_name WeatherRainSplash3D
extends Node3D

## Optional flat-ground rain response: expanding ripples and short droplets.
## Set ground_height at runtime for moving platforms or custom level logic.

const RIPPLE_COUNTS := {
	WeatherController3D.Quality.LOW: 35,
	WeatherController3D.Quality.MEDIUM: 85,
	WeatherController3D.Quality.HIGH: 160,
}
const DROPLET_COUNTS := {
	WeatherController3D.Quality.LOW: 45,
	WeatherController3D.Quality.MEDIUM: 110,
	WeatherController3D.Quality.HIGH: 220,
}

@export var controller: WeatherController3D
@export var camera: Camera3D
@export var enabled := true
@export_range(-1000.0, 1000.0, 0.05) var ground_height := 0.02
@export_range(1.0, 30.0, 0.5) var follow_radius := 9.0
@export_range(0.0, 1.0, 0.01) var intensity_multiplier := 0.72

var _ripples: GPUParticles3D
var _droplets: GPUParticles3D
var _last_state: Dictionary = {}


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherRainSplash3D requires a WeatherController3D.")
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
		global_position = Vector3(target.x, ground_height, target.z)


func set_ground_height(value: float) -> void:
	ground_height = value


func get_allocated_particle_count() -> int:
	return _ripples.amount + _droplets.amount


func _create_emitters() -> void:
	_ripples = _create_ripple_emitter()
	_droplets = _create_droplet_emitter()
	add_child(_ripples)
	add_child(_droplets)


func _create_ripple_emitter() -> GPUParticles3D:
	var emitter := _base_emitter("RainRipples")
	emitter.lifetime = 0.55
	emitter.randomness = 0.35
	emitter.preprocess = 0.5
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(follow_radius, 0.01, follow_radius)
	process.direction = Vector3.ZERO
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.45
	process.scale_max = 1.25
	process.scale_curve = _create_scale_curve(0.15, 1.0)
	process.alpha_curve = _create_alpha_curve()
	process.color = Color(0.68, 0.8, 0.92, 0.48)
	emitter.process_material = process
	var material := _create_unshaded_material(_create_ring_texture())
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var mesh := QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2(0.42, 0.42)
	mesh.material = material
	emitter.draw_pass_1 = mesh
	return emitter


func _create_droplet_emitter() -> GPUParticles3D:
	var emitter := _base_emitter("RainSplashDroplets")
	emitter.lifetime = 0.42
	emitter.randomness = 0.6
	emitter.preprocess = 0.4
	emitter.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(follow_radius, 0.02, follow_radius)
	process.direction = Vector3.UP
	process.spread = 68.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 2.4
	process.gravity = Vector3(0.0, -8.5, 0.0)
	process.scale_min = 0.55
	process.scale_max = 1.25
	process.alpha_curve = _create_alpha_curve()
	process.color = Color(0.72, 0.84, 0.95, 0.55)
	emitter.process_material = process
	var material := _create_unshaded_material(_create_streak_texture())
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.13)
	mesh.material = material
	emitter.draw_pass_1 = mesh
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
	emitter.visibility_aabb = AABB(Vector3(-15.0, -2.0, -15.0), Vector3(30.0, 6.0, 30.0))
	return emitter


func _create_unshaded_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _create_scale_curve(start_value: float, end_value: float) -> CurveTexture:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = maxf(end_value, 1.0)
	curve.add_point(Vector2(0.0, start_value))
	curve.add_point(Vector2(1.0, end_value))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _create_alpha_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.12, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _create_ring_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var uv := Vector2((float(x) + 0.5) / size, (float(y) + 0.5) / size)
			var distance_from_center := uv.distance_to(Vector2(0.5, 0.5)) * 2.0
			var outer := 1.0 - smoothstep(0.88, 1.0, distance_from_center)
			var inner := smoothstep(0.7, 0.86, distance_from_center)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, outer * inner))
	return ImageTexture.create_from_image(image)


func _create_streak_texture() -> ImageTexture:
	var width := 16
	var height := 64
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var uv := Vector2((float(x) + 0.5) / width, (float(y) + 0.5) / height)
			var horizontal := 1.0 - smoothstep(0.12, 0.5, absf(uv.x - 0.5))
			var vertical := smoothstep(0.0, 0.2, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, horizontal * vertical))
	return ImageTexture.create_from_image(image)


func _apply_state(state: Dictionary) -> void:
	if _ripples == null:
		return
	_last_state = state.duplicate(true)
	var intensity := clampf(float(state.get("rain_intensity", 0.0)) * intensity_multiplier, 0.0, 1.0)
	if not enabled:
		intensity = 0.0
	_set_intensity(_ripples, intensity)
	_set_intensity(_droplets, intensity * 0.78)


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
	if _ripples == null:
		return
	_ripples.amount = int(RIPPLE_COUNTS.get(value, RIPPLE_COUNTS[WeatherController3D.Quality.HIGH]))
	_droplets.amount = int(DROPLET_COUNTS.get(value, DROPLET_COUNTS[WeatherController3D.Quality.HIGH]))
