class_name WeatherLightning3D
extends Node

## Automatic and manually triggered lightning flashes.
## Thunder is exposed as a delayed event so projects can supply their own audio.

signal flash_started(strength: float)
signal flash_finished

@export var controller: WeatherController3D
@export var sun_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_range(0.0, 5.0, 0.05) var thunder_delay_min := 0.35
@export_range(0.0, 10.0, 0.05) var thunder_delay_max := 2.2
@export var automatic_lightning := true

var _rng := RandomNumberGenerator.new()
var _enabled := false
var _strength := 0.0
var _interval_min := 8.0
var _interval_max := 20.0
var _time_until_flash := 10.0
var _flash_active := false
var _flash_steps: Array[Vector2] = []
var _flash_step_index := 0
var _flash_step_elapsed := 0.0
var _restore_light_energy := 1.0
var _restore_environment_energy := 1.0


func _ready() -> void:
	if controller == null:
		controller = get_parent() as WeatherController3D
	if controller == null:
		push_warning("WeatherLightning3D requires a WeatherController3D.")
		set_process(false)
		return
	if sun_light == null:
		sun_light = controller.sun_light
	if world_environment == null:
		world_environment = controller.world_environment
	_rng.randomize()
	controller.state_changed.connect(_on_state_changed)
	controller.lightning_requested.connect(_on_lightning_requested)
	_on_state_changed(controller.get_effective_state())


func _process(delta: float) -> void:
	if _flash_active:
		_process_flash(maxf(delta, 0.0))
		return
	if not automatic_lightning or not _enabled:
		return
	_time_until_flash -= maxf(delta, 0.0)
	if _time_until_flash <= 0.0:
		var delay := _rng.randf_range(minf(thunder_delay_min, thunder_delay_max), maxf(thunder_delay_min, thunder_delay_max))
		controller.trigger_lightning(_strength, delay)
		_schedule_next_flash()


func is_flashing() -> bool:
	return _flash_active


func _on_state_changed(state: Dictionary) -> void:
	_enabled = float(state.get("lightning_enabled", 0.0)) >= 0.5
	_strength = clampf(float(state.get("lightning_strength", 0.0)), 0.0, 1.0)
	_interval_min = maxf(float(state.get("lightning_interval_min", 8.0)), 0.5)
	_interval_max = maxf(float(state.get("lightning_interval_max", 20.0)), _interval_min)
	if not _flash_active:
		_capture_restore_values()
	if _enabled and _time_until_flash <= 0.0:
		_schedule_next_flash()


func _on_lightning_requested(requested_strength: float) -> void:
	_start_flash(clampf(requested_strength, 0.0, 1.0))


func _start_flash(requested_strength: float) -> void:
	if requested_strength <= 0.0:
		return
	_capture_restore_values()
	var peak := 1.0 + requested_strength * 5.5
	var secondary := 1.0 + requested_strength * 3.2
	if _rng.randf() < 0.55:
		_flash_steps = [
			Vector2(0.055, peak),
			Vector2(0.06, 0.72),
			Vector2(0.09, secondary),
			Vector2(0.16, 1.0),
		]
	else:
		_flash_steps = [
			Vector2(0.085, peak),
			Vector2(0.18, 1.0),
		]
	_flash_step_index = 0
	_flash_step_elapsed = 0.0
	_flash_active = true
	_apply_flash_multiplier(_flash_steps[0].y)
	flash_started.emit(requested_strength)


func _process_flash(delta: float) -> void:
	_flash_step_elapsed += delta
	while _flash_active and _flash_step_elapsed >= _flash_steps[_flash_step_index].x:
		_flash_step_elapsed -= _flash_steps[_flash_step_index].x
		_flash_step_index += 1
		if _flash_step_index >= _flash_steps.size():
			_finish_flash()
			return
		_apply_flash_multiplier(_flash_steps[_flash_step_index].y)


func _finish_flash() -> void:
	_flash_active = false
	if sun_light != null:
		sun_light.light_energy = _restore_light_energy
	var environment := _get_environment()
	if environment != null:
		environment.background_energy_multiplier = _restore_environment_energy
	flash_finished.emit()


func _apply_flash_multiplier(multiplier: float) -> void:
	if sun_light != null:
		sun_light.light_energy = _restore_light_energy * multiplier
	var environment := _get_environment()
	if environment != null:
		environment.background_energy_multiplier = _restore_environment_energy * lerpf(1.0, multiplier, 0.42)


func _capture_restore_values() -> void:
	if sun_light != null:
		_restore_light_energy = sun_light.light_energy
	var environment := _get_environment()
	if environment != null:
		_restore_environment_energy = environment.background_energy_multiplier


func _schedule_next_flash() -> void:
	_time_until_flash = _rng.randf_range(_interval_min, _interval_max)


func _get_environment() -> Environment:
	if world_environment == null:
		return null
	return world_environment.environment
