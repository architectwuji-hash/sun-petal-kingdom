class_name WeatherProfile
extends Resource

## Serializable definition of one weather condition.
## WeatherController3D converts profiles into interpolated runtime state.

enum PrecipitationType {
	NONE,
	RAIN,
	SNOW,
	AIRBORNE,
}

enum AirborneType {
	DUST,
	ASH,
	POLLEN,
}

@export_group("Identity")
@export var display_name := "Clear"

@export_group("Precipitation")
@export var precipitation_type: PrecipitationType = PrecipitationType.NONE
@export_range(0.0, 1.0, 0.01) var precipitation_intensity := 0.0
@export_range(0.1, 3.0, 0.05) var particle_size_scale := 1.0
@export_range(0.1, 3.0, 0.05) var fall_speed_scale := 1.0
@export_range(0.0, 2.0, 0.01) var turbulence := 0.0
@export var precipitation_color := Color.WHITE

@export_group("Airborne Particles")
@export var airborne_type: AirborneType = AirborneType.DUST
@export_range(0.1, 3.0, 0.05) var airborne_size_scale := 1.0
@export_range(-2.0, 2.0, 0.05) var airborne_buoyancy := 0.0

@export_group("Wind")
@export var wind_direction := Vector3(1.0, 0.0, 0.0)
@export_range(0.0, 40.0, 0.1, "or_greater") var wind_speed := 0.0
@export_range(0.0, 1.0, 0.01) var gust_strength := 0.0
@export_range(0.0, 2.0, 0.01) var gust_frequency := 0.0

@export_group("Fog")
@export_range(0.0, 1.0, 0.001) var fog_density := 0.0
@export var fog_color := Color(0.65, 0.68, 0.72)
@export_range(-1000.0, 1000.0, 0.1) var fog_height := 0.0
@export_range(0.0, 10.0, 0.01) var fog_height_density := 0.0
@export_range(0.0, 1.0, 0.01) var mist_intensity := 0.0

@export_group("Lighting")
@export_range(0.0, 2.0, 0.01) var environment_brightness := 1.0
@export_range(0.0, 2.0, 0.01) var sun_energy_multiplier := 1.0
@export var sun_color := Color.WHITE
@export var ambient_tint := Color.WHITE

@export_group("Storm")
@export var lightning_enabled := false
@export_range(0.5, 120.0, 0.1) var lightning_interval_min := 8.0
@export_range(0.5, 120.0, 0.1) var lightning_interval_max := 20.0
@export_range(0.0, 1.0, 0.01) var lightning_strength := 0.0

@export_group("Audio")
@export_range(0.0, 1.0, 0.01) var rain_audio_level := 0.0
@export_range(0.0, 1.0, 0.01) var wind_audio_level := 0.0


func to_state() -> Dictionary:
	var normalized_wind := wind_direction
	normalized_wind.y = 0.0
	if normalized_wind.length_squared() > 0.0001:
		normalized_wind = normalized_wind.normalized()
	else:
		normalized_wind = Vector3.RIGHT

	var rain := 0.0
	var snow := 0.0
	var airborne := 0.0
	match precipitation_type:
		PrecipitationType.RAIN:
			rain = precipitation_intensity
		PrecipitationType.SNOW:
			snow = precipitation_intensity
		PrecipitationType.AIRBORNE:
			airborne = precipitation_intensity

	return {
		"rain_intensity": rain,
		"snow_intensity": snow,
		"airborne_intensity": airborne,
		"particle_size_scale": particle_size_scale,
		"fall_speed_scale": fall_speed_scale,
		"turbulence": turbulence,
		"precipitation_color": precipitation_color,
		"airborne_type": airborne_type,
		"airborne_size_scale": airborne_size_scale,
		"airborne_buoyancy": airborne_buoyancy,
		"wind_direction": normalized_wind,
		"wind_speed": wind_speed,
		"gust_strength": gust_strength,
		"gust_frequency": gust_frequency,
		"fog_density": fog_density,
		"fog_color": fog_color,
		"fog_height": fog_height,
		"fog_height_density": fog_height_density,
		"mist_intensity": mist_intensity,
		"environment_brightness": environment_brightness,
		"sun_energy_multiplier": sun_energy_multiplier,
		"sun_color": sun_color,
		"ambient_tint": ambient_tint,
		"lightning_enabled": 1.0 if lightning_enabled else 0.0,
		"lightning_interval_min": minf(lightning_interval_min, lightning_interval_max),
		"lightning_interval_max": maxf(lightning_interval_min, lightning_interval_max),
		"lightning_strength": lightning_strength,
		"rain_audio_level": rain_audio_level,
		"wind_audio_level": wind_audio_level,
	}


static func clear_state() -> Dictionary:
	return WeatherProfile.new().to_state()
