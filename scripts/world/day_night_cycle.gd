extends Node
class_name DayNightCycle
## Day/night cycle for the forest scenes.
## Drives the scene's existing "Sun" DirectionalLight3D and WorldEnvironment
## (ProceduralSkyMaterial) - no extra assets. Adds a dim blue moonlight and a
## procedurally generated star field that fades in at night.
## Added automatically by forest_zone_3d.gd, so every scene using that script
## gets it without editing the .tscn.

signal day_started
signal night_started

## One full day + night, in seconds.
@export var cycle_seconds: float = 180.0
## Share of the cycle that is daytime (sun above the horizon).
@export_range(0.2, 0.8) var day_fraction: float = 0.62
## Where in the cycle the game starts (0 = sunrise, day_fraction = sunset).
@export_range(0.0, 1.0) var start_time: float = 0.12
## Highest the sun climbs at noon, in degrees.
@export var max_sun_elevation: float = 62.0

const NIGHT_SKY_TOP := Color(0.015, 0.02, 0.06)
const NIGHT_HORIZON := Color(0.05, 0.07, 0.14)
const DUSK_HORIZON := Color(0.98, 0.52, 0.28)
const DUSK_SUN := Color(1.0, 0.55, 0.3)
const NIGHT_AMBIENT := Color(0.28, 0.33, 0.55)
const NIGHT_FOG := Color(0.07, 0.09, 0.16)
const MOON_COLOR := Color(0.6, 0.7, 1.0)
const MOON_ENERGY := 0.28

var time: float = 0.0          # 0..1 through the cycle
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _was_day := true

# Daytime values captured from the scene so the day still looks exactly as
# the scene was set up.
var _day_sun_color: Color
var _day_sun_energy: float
var _day_sky_top: Color
var _day_horizon: Color
var _day_ground_horizon: Color
var _day_ambient_energy: float
var _day_fog_color: Color
var _sun_azimuth: float = 0.0


func _ready() -> void:
	time = start_time
	var scene := get_parent()
	_sun = scene.get_node_or_null("Sun") as DirectionalLight3D
	if _sun == null:
		for c in scene.get_children():
			if c is DirectionalLight3D:
				_sun = c
				break
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		_sun.shadow_enabled = true
		scene.add_child.call_deferred(_sun)
	_day_sun_color = _sun.light_color
	_day_sun_energy = _sun.light_energy
	# Keep the compass direction the scene's sun already came from.
	var fwd := -_sun.global_transform.basis.z if _sun.is_inside_tree() else -_sun.transform.basis.z
	_sun_azimuth = atan2(-fwd.x, -fwd.z)

	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = MOON_COLOR
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	scene.add_child.call_deferred(_moon)

	for c in scene.get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment:
			_env = (c as WorldEnvironment).environment
			break
	if _env:
		_day_ambient_energy = _env.ambient_light_energy
		_day_fog_color = _env.fog_light_color
		_env.ambient_light_color = NIGHT_AMBIENT
		if _env.sky and _env.sky.sky_material is ProceduralSkyMaterial:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
			_day_sky_top = _sky.sky_top_color
			_day_horizon = _sky.sky_horizon_color
			_day_ground_horizon = _sky.ground_horizon_color
			_sky.sky_cover = _make_star_texture()
	_apply()


func _process(delta: float) -> void:
	time = fmod(time + delta / cycle_seconds, 1.0)
	_apply()


func is_night() -> bool:
	return time >= day_fraction


## Sun elevation in radians: rises 0 -> max -> 0 over the day, then dips
## below the horizon for the night.
func _sun_elevation() -> float:
	if time < day_fraction:
		return sin(PI * time / day_fraction) * deg_to_rad(max_sun_elevation)
	return -sin(PI * (time - day_fraction) / (1.0 - day_fraction)) * deg_to_rad(max_sun_elevation)


func _apply() -> void:
	var elev := _sun_elevation()
	var s := sin(elev)
	# 0 = full night, 1 = full day, with a soft twilight band around the horizon.
	var day_amt := smoothstep(-0.18, 0.4, s)
	var twilight := clampf(1.0 - absf(s) / 0.4, 0.0, 1.0)

	# Sun travels east -> west over the day; moon takes the opposite path.
	var arc := time / day_fraction if time < day_fraction else (time - day_fraction) / (1.0 - day_fraction)
	var az := _sun_azimuth + lerpf(-1.4, 1.4, arc)
	var to_sun := Vector3(sin(az) * cos(elev), s, cos(az) * cos(elev)).normalized()
	if not is_night():
		_aim(_sun, to_sun)
	else:
		_aim(_sun, Vector3(to_sun.x, 0.05, to_sun.z))   # parked just under the horizon
		_aim(_moon, Vector3(-to_sun.x, -to_sun.y, -to_sun.z))

	_sun.light_energy = _day_sun_energy * day_amt
	_sun.light_color = _day_sun_color.lerp(DUSK_SUN, twilight * 0.8)
	_sun.shadow_enabled = day_amt > 0.05
	if _moon and _moon.is_inside_tree():
		_moon.light_energy = MOON_ENERGY * (1.0 - day_amt)
		if not is_night():
			_aim(_moon, Vector3(-to_sun.x, 0.3, -to_sun.z))

	if _sky:
		_sky.sky_top_color = NIGHT_SKY_TOP.lerp(_day_sky_top, day_amt)
		var hz := NIGHT_HORIZON.lerp(_day_horizon, day_amt).lerp(DUSK_HORIZON, twilight * 0.65)
		_sky.sky_horizon_color = hz
		_sky.ground_horizon_color = NIGHT_HORIZON.lerp(_day_ground_horizon, day_amt).lerp(DUSK_HORIZON, twilight * 0.4)
		_sky.sky_cover_modulate = Color(1, 1, 1, clampf(1.0 - day_amt * 1.6, 0.0, 1.0))
	if _env:
		_env.ambient_light_energy = lerpf(0.35, _day_ambient_energy, day_amt)
		_env.ambient_light_sky_contribution = day_amt
		_env.fog_light_color = NIGHT_FOG.lerp(_day_fog_color, day_amt).lerp(DUSK_HORIZON * 0.8, twilight * 0.35)

	var day_now := not is_night()
	if day_now != _was_day:
		_was_day = day_now
		if day_now:
			day_started.emit()
		else:
			night_started.emit()


func _aim(light: DirectionalLight3D, to_light: Vector3) -> void:
	if light == null or to_light.length_squared() < 0.0001:
		return
	# A DirectionalLight3D shines along its -Z axis, i.e. away from the light.
	var dir := -to_light.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	light.basis = Basis.looking_at(dir, up)


## Equirectangular star field for the sky cover - random white dots of
## varying brightness, only in the upper half (below the horizon is ground).
func _make_star_texture() -> ImageTexture:
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 2200:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(h * 0.48))
		var b := rng.randf_range(0.35, 1.0)
		var c := Color(b, b, lerpf(b, 1.0, 0.3), b)
		img.set_pixel(x, y, c)
		if b > 0.9 and x + 1 < w and y + 1 < h:   # a few bigger, brighter stars
			img.set_pixel(x + 1, y, c)
			img.set_pixel(x, y + 1, c)
			img.set_pixel(x + 1, y + 1, c)
	return ImageTexture.create_from_image(img)
