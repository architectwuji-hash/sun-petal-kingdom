class_name WeatherController3D
extends Node3D

## Central runtime API for weather state, transitions, quality, and zones.
## Visual components consume get_effective_state() or the state_changed signal.

signal transition_started(from_profile: WeatherProfile, to_profile: WeatherProfile, duration: float)
signal transition_midpoint(profile: WeatherProfile)
signal transition_completed(profile: WeatherProfile)
signal state_changed(state: Dictionary)
signal quality_changed(quality: Quality)
signal lightning_requested(strength: float)
signal thunder_requested(delay_seconds: float, strength: float)

enum Quality {
	LOW,
	MEDIUM,
	HIGH,
}

const QUALITY_PARTICLE_SCALES := {
	Quality.LOW: 0.35,
	Quality.MEDIUM: 0.65,
	Quality.HIGH: 1.0,
}

@export_group("Scene References")
@export var camera: Camera3D
@export var effect_target: Node3D
@export var effect_target_offset := Vector3.ZERO
@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

@export_group("Initial State")
@export var initial_profile: WeatherProfile
@export var apply_initial_profile_on_ready := true
@export var quality: Quality = Quality.HIGH

@export_group("Environment Ownership")
@export var manage_environment := true
## Fog never drops below this, so distant scenery fades out instead of popping in.
@export_range(0.0, 1.0, 0.001) var min_fog_density := 0.0
@export var duplicate_environment_on_ready := true

@export_group("Forward+ Enhancement")
@export var enable_forward_plus_volumetric_fog := true
@export_range(0.0, 4.0, 0.05) var volumetric_fog_density_scale := 1.0
@export_range(0.0, 1.0, 0.01) var volumetric_fog_sky_affect := 1.0

var current_profile: WeatherProfile

var _base_profile: WeatherProfile
var _clear_profile: WeatherProfile
var _current_state: Dictionary = WeatherProfile.clear_state()
var _transition_from: Dictionary = {}
var _transition_to: Dictionary = {}
var _transition_profile: WeatherProfile
var _transition_duration := 0.0
var _transition_elapsed := 0.0
var _transition_active := false
var _midpoint_emitted := false
var _intensity_scale := 1.0
var _base_sun_energy := 1.0
var _zone_requests: Array[Dictionary] = []
var _zone_order := 0
var _active_zone: Node


func _ready() -> void:
	add_to_group(&"weather_controller")
	_clear_profile = WeatherProfile.new()
	_clear_profile.display_name = "Clear"
	if sun_light != null:
		_base_sun_energy = sun_light.light_energy
	_prepare_environment()
	_base_profile = initial_profile if initial_profile != null else _clear_profile
	if apply_initial_profile_on_ready:
		_apply_profile_immediately(_base_profile)
	else:
		_emit_state()


func _process(delta: float) -> void:
	if not _transition_active:
		return
	_transition_elapsed += maxf(delta, 0.0)
	var weight := clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
	_current_state = _interpolate_state(_transition_from, _transition_to, _smoothstep(weight))
	_apply_runtime_state()
	if weight >= 0.5 and not _midpoint_emitted:
		_midpoint_emitted = true
		transition_midpoint.emit(_transition_profile)
	if weight >= 1.0:
		_transition_active = false
		current_profile = _transition_profile
		transition_completed.emit(current_profile)


func transition_to(profile: WeatherProfile, duration := 2.0) -> void:
	if profile == null:
		push_warning("WeatherController3D.transition_to received a null profile.")
		return
	_base_profile = profile
	if _active_zone != null:
		return
	_start_transition(profile, duration)


func clear_weather(duration := 2.0) -> void:
	if _clear_profile == null:
		_clear_profile = WeatherProfile.new()
		_clear_profile.display_name = "Clear"
	transition_to(_clear_profile, duration)


func set_intensity(value: float) -> void:
	_intensity_scale = maxf(value, 0.0)
	_apply_runtime_state()


func get_intensity() -> float:
	return _intensity_scale


func set_camera(value: Camera3D) -> void:
	camera = value


func set_effect_target(value: Node3D) -> void:
	effect_target = value


func get_effect_anchor_position() -> Vector3:
	if effect_target != null and is_instance_valid(effect_target):
		return effect_target.global_position + effect_target_offset
	if camera != null and is_instance_valid(camera):
		return camera.global_position
	return global_position


func set_wind(direction: Vector3, strength: float) -> void:
	var horizontal_direction := Vector3(direction.x, 0.0, direction.z)
	if horizontal_direction.length_squared() > 0.0001:
		horizontal_direction = horizontal_direction.normalized()
	else:
		horizontal_direction = Vector3.RIGHT
	_current_state["wind_direction"] = horizontal_direction
	_current_state["wind_speed"] = maxf(strength, 0.0)
	if _transition_active:
		_transition_from = _current_state.duplicate(true)
		_transition_to["wind_direction"] = horizontal_direction
		_transition_to["wind_speed"] = maxf(strength, 0.0)
	_apply_runtime_state()


func set_quality(value: Quality) -> void:
	if quality == value:
		return
	quality = value
	quality_changed.emit(quality)
	_emit_state()


func get_quality_particle_scale() -> float:
	return QUALITY_PARTICLE_SCALES.get(quality, 1.0)


func get_wind_velocity(time_offset := 0.0) -> Vector3:
	var direction: Vector3 = _current_state.get("wind_direction", Vector3.RIGHT)
	var base_speed := maxf(float(_current_state.get("wind_speed", 0.0)), 0.0)
	var gust_strength := clampf(float(_current_state.get("gust_strength", 0.0)), 0.0, 1.0)
	var gust_frequency := maxf(float(_current_state.get("gust_frequency", 0.0)), 0.0)
	var turbulence := maxf(float(_current_state.get("turbulence", 0.0)), 0.0)
	if base_speed <= 0.0:
		return Vector3.ZERO
	var elapsed := Time.get_ticks_msec() * 0.001 + time_offset
	var primary_wave := sin(elapsed * gust_frequency * TAU)
	var secondary_wave := sin(elapsed * gust_frequency * 0.37 * TAU + 1.7)
	var gust_wave := clampf(primary_wave * 0.7 + secondary_wave * 0.3, -1.0, 1.0)
	var multiplier := 1.0 + gust_wave * gust_strength * 0.45
	var perpendicular := Vector3(-direction.z, 0.0, direction.x)
	var turbulence_wave := sin(elapsed * 1.73 + 0.8) * 0.65 + sin(elapsed * 3.17 + 2.1) * 0.35
	return direction * base_speed * maxf(multiplier, 0.0) + perpendicular * turbulence_wave * turbulence


func get_state() -> Dictionary:
	return _current_state.duplicate(true)


func get_effective_state() -> Dictionary:
	var state := get_state()
	for key: String in ["rain_intensity", "snow_intensity", "airborne_intensity", "mist_intensity", "fog_density", "rain_audio_level", "wind_audio_level"]:
		state[key] = float(state[key]) * _intensity_scale
	state["quality"] = quality
	state["quality_particle_scale"] = get_quality_particle_scale()
	return state


func is_transitioning() -> bool:
	return _transition_active


func get_target_profile() -> WeatherProfile:
	return _transition_profile if _transition_active else current_profile


func is_volumetric_fog_available() -> bool:
	if RenderingServer.has_method("get_current_rendering_method"):
		return str(RenderingServer.call("get_current_rendering_method")) == "forward_plus"
	var configured_method := str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method",
		"gl_compatibility"
	))
	return configured_method != "mobile" and RenderingServer.get_rendering_device() != null


func trigger_lightning(strength := -1.0, thunder_delay := 0.0) -> void:
	var effective_strength := strength
	if effective_strength < 0.0:
		effective_strength = float(_current_state.get("lightning_strength", 0.0))
	effective_strength = clampf(effective_strength, 0.0, 1.0)
	lightning_requested.emit(effective_strength)
	thunder_requested.emit(maxf(thunder_delay, 0.0), effective_strength)


func request_zone(zone: Node, profile: WeatherProfile, priority: int, transition_duration: float) -> void:
	if zone == null or profile == null:
		return
	release_zone(zone, false)
	_zone_order += 1
	_zone_requests.append({
		"zone": zone,
		"profile": profile,
		"priority": priority,
		"duration": maxf(transition_duration, 0.0),
		"order": _zone_order,
	})
	_refresh_active_zone()


func release_zone(zone: Node, refresh := true, exit_duration := 1.0) -> void:
	for index in range(_zone_requests.size() - 1, -1, -1):
		if _zone_requests[index]["zone"] == zone:
			_zone_requests.remove_at(index)
	if refresh:
		_refresh_active_zone(maxf(exit_duration, 0.0))


func _start_transition(profile: WeatherProfile, duration: float) -> void:
	var safe_duration := maxf(duration, 0.0)
	var from_profile := current_profile
	if safe_duration <= 0.0:
		transition_started.emit(from_profile, profile, 0.0)
		_apply_profile_immediately(profile)
		transition_midpoint.emit(profile)
		transition_completed.emit(profile)
		return
	_transition_from = _current_state.duplicate(true)
	_transition_to = profile.to_state()
	_transition_profile = profile
	_transition_duration = safe_duration
	_transition_elapsed = 0.0
	_transition_active = true
	_midpoint_emitted = false
	transition_started.emit(from_profile, profile, safe_duration)


func _apply_profile_immediately(profile: WeatherProfile) -> void:
	_transition_active = false
	_transition_profile = profile
	current_profile = profile
	_current_state = profile.to_state()
	_apply_runtime_state()


func _prepare_environment() -> void:
	if not manage_environment or world_environment == null or world_environment.environment == null:
		return
	if duplicate_environment_on_ready:
		world_environment.environment = world_environment.environment.duplicate(true)


func _apply_runtime_state() -> void:
	var state := get_effective_state()
	if manage_environment and world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		var density := clampf(maxf(float(state["fog_density"]), min_fog_density), 0.0, 1.0)
		environment.fog_enabled = density > 0.0001 or float(state["fog_height_density"]) > 0.0001
		environment.fog_density = density
		environment.fog_light_color = state["fog_color"]
		environment.fog_height = float(state["fog_height"])
		environment.fog_height_density = float(state["fog_height_density"])
		environment.background_energy_multiplier = maxf(float(state["environment_brightness"]), 0.0)
		environment.ambient_light_color = state["ambient_tint"]
		if is_volumetric_fog_available():
			var use_volumetrics := enable_forward_plus_volumetric_fog and density > 0.0001
			environment.volumetric_fog_enabled = use_volumetrics
			environment.volumetric_fog_density = density * maxf(volumetric_fog_density_scale, 0.0)
			environment.volumetric_fog_albedo = state["fog_color"]
			environment.volumetric_fog_sky_affect = clampf(volumetric_fog_sky_affect, 0.0, 1.0)
	if sun_light != null:
		sun_light.light_energy = _base_sun_energy * maxf(float(state["sun_energy_multiplier"]), 0.0)
		sun_light.light_color = state["sun_color"]
	state_changed.emit(state)


func _emit_state() -> void:
	state_changed.emit(get_effective_state())


func _refresh_active_zone(fallback_duration := 1.0) -> void:
	var previous_zone := _active_zone
	var selected: Dictionary = {}
	for request: Dictionary in _zone_requests:
		var request_zone_node: Node = request["zone"]
		if not is_instance_valid(request_zone_node):
			continue
		if selected.is_empty() or _zone_request_precedes(request, selected):
			selected = request
	if selected.is_empty():
		_active_zone = null
		if previous_zone != null:
			_start_transition(_base_profile if _base_profile != null else _clear_profile, fallback_duration)
		return
	_active_zone = selected["zone"]
	if _active_zone != previous_zone:
		_start_transition(selected["profile"], float(selected["duration"]))


func _zone_request_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_priority := int(left["priority"])
	var right_priority := int(right["priority"])
	if left_priority != right_priority:
		return left_priority > right_priority
	return int(left["order"]) > int(right["order"])


func _interpolate_state(from_state: Dictionary, to_state: Dictionary, weight: float) -> Dictionary:
	var result := {}
	for key: Variant in to_state:
		var from_value: Variant = from_state.get(key, to_state[key])
		var to_value: Variant = to_state[key]
		if key == "airborne_type":
			result[key] = to_value if weight >= 0.5 else from_value
			continue
		match typeof(to_value):
			TYPE_FLOAT, TYPE_INT:
				result[key] = lerpf(float(from_value), float(to_value), weight)
			TYPE_VECTOR3:
				result[key] = (from_value as Vector3).lerp(to_value, weight)
			TYPE_COLOR:
				result[key] = (from_value as Color).lerp(to_value, weight)
			_:
				result[key] = to_value if weight >= 0.5 else from_value
	var wind_direction: Vector3 = result.get("wind_direction", Vector3.RIGHT)
	wind_direction.y = 0.0
	result["wind_direction"] = wind_direction.normalized() if wind_direction.length_squared() > 0.0001 else Vector3.RIGHT
	return result


func _smoothstep(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
