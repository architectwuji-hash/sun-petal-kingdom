class_name MonsterAI
extends CharacterBody3D

enum State { WANDER, CHASE, SEARCH }

signal attacked_target(target: Node3D, damage: float, knockback_dir: Vector3, force: float)

@export_group("Targeting & Detection")
@export var target_group: String = "player"
@export var sight_detection_range := 20.0
@export var lose_range := 30.0
@export var hear_range := 25.0
@export var sense_variance := 10.0
@export var sense_shift_interval := 5.0
@export var eye_height_offset := Vector3(0, 1.5, 0)

@export_group("Movement")
@export var speed := 4.0
@export var chase_speed := 7.0
@export var roam_radius := 80.0
@export var rotation_speed := 8.0
@export var wander_delay := 2.0
@export var head_start_time := 30.0

@export_group("Attacking")
@export var attack_damage := 25.0
@export var attack_knockback := 8.0

@export_group("Audio")
@export var shriek_sound: AudioStream
@export var ambient_sounds: Array[AudioStream] = []
@export var ambient_interval_min := 10.0
@export var ambient_interval_max := 30.0
@export var ambient_volume_min_db := -20.0
@export var ambient_volume_max_db := -5.0

@export_group("Required Node Paths")
@export var nav_agent_path: NodePath = "NavigationAgent3D"
@export var vision_ray_path: NodePath = "VisionRay"
@export var attack_zone_path: NodePath = "AttackZone"
@export var audio_player_path: NodePath = "AudioStreamPlayer3D"
@export var ambient_audio_player_path: NodePath = "AmbienceAudioPlayer"

var state : State = State.WANDER
var target_node: Node3D = null
var roam_centre: Vector3
var wander_timer := 0.0
var head_start_remaining := -1.0
var screech_played := false
var is_active := false
var last_known_position: Vector3
var y_velocity := 0.0

var base_detection_range := 0.0
var base_hearing_range := 0.0
var sense_timer := 0.0

var chase_speed_multiplier := 1.0
const FAST_CHASE_CHANCE := 0.2
const FAST_CHASE_MULTIPLIER := 1.25
const ENRAGE_CHANCE := 0.1
const ENRAGE_MULTIPLIER := 2.0

var vision_check_cooldown := 0.0
const VISION_CHECK_INTERVAL := 0.15
var last_can_see_target := false

var active_knockback := Vector3.ZERO

@onready var agent: NavigationAgent3D = get_node_or_null(nav_agent_path)
@onready var vision_ray: RayCast3D = get_node_or_null(vision_ray_path)
@onready var attack_zone: Area3D = get_node_or_null(attack_zone_path)
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null(audio_player_path)
@onready var ambient_audio_player: AudioStreamPlayer3D = get_node_or_null(ambient_audio_player_path)
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# force active state for testing -- remove when desired
	is_active = true
	head_start_remaining = 0.0
	
	#wait for Godot's NavServer to sync
	await get_tree().physics_frame
	
	roam_centre = global_position
	base_detection_range = sight_detection_range
	base_hearing_range = hear_range

	if attack_zone:
		attack_zone.body_entered.connect(_on_attack_zone_entered)

	if head_start_remaining > 0.0:
		await get_tree().create_timer(head_start_remaining).timeout
	
	is_active = true
	_try_find_target()

	if ambient_audio_player:
		ambient_audio_player.unit_size = 10.0
		ambient_audio_player.max_distance = 50.0
		_reset_ambient_timer()

func _physics_process(delta: float) -> void:
	
	# render debug collision spheres in debug builds only
	if OS.is_debug_build():
		if has_node("SightRangeDebugSphere") and $SightRangeDebugSphere.mesh:
			$SightRangeDebugSphere.mesh.radius = sight_detection_range
		if  has_node ("HearingRangeDebugSphere") and $HearingRangeDebugSphere.mesh:
			$SightRangeDebugSphere.mesh.radius = hear_range
	
	if not is_active:
		if head_start_remaining > 0.0:
			head_start_remaining = maxf(0.0, head_start_remaining - delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	if vision_check_cooldown > 0.0:
		vision_check_cooldown -= delta

	_apply_gravity(delta)

	if not ambient_sounds.is_empty():
		ambient_timer_process(delta)

	if not _try_find_target():
		move_and_slide()
		return

	# Handle target in sight vs loss
	if is_instance_valid(target_node):
		var target_is_hidden = target_node.get("is_inside_building") == true
		if target_is_hidden and state == State.CHASE:
			state = State.WANDER
			screech_played = false
			chase_speed_multiplier = 1.0

	var distance = global_position.distance_to(target_node.global_position)

	match state:
		State.WANDER:
			wander(distance, delta)
		State.CHASE:
			var can_see = check_vision()
			var in_range = distance <= lose_range
			if can_see and in_range:
				chase_target(delta)
			else:
				state = State.SEARCH
				last_known_position = target_node.global_position
				screech_played = false
		State.SEARCH:
			search(delta)

	_update_sensory_variance(delta)

	# Apply external knockback vector decay
	if active_knockback.length() > 0.1:
		velocity.x = active_knockback.x
		velocity.z = active_knockback.z
		active_knockback = active_knockback.move_toward(Vector3.ZERO, delta * 30.0)

	move_and_slide()

func wander(distance: float, delta: float) -> void:
	wander_timer -= delta
	if distance <= sight_detection_range and check_vision():
		state = State.CHASE
		if not screech_played and audio_player and shriek_sound:
			audio_player.stream = shriek_sound
			audio_player.play()
			screech_played = true
		return

	if agent and agent.is_navigation_finished() and wander_timer <= 0:
		var random_pt = Vector3(randf_range(-roam_radius, roam_radius), 0, randf_range(-roam_radius, roam_radius))
		agent.target_position = roam_centre + random_pt
		wander_timer = wander_delay

	move_to_target_dir(speed, delta)

func chase_target(delta: float) -> void:
	if not is_instance_valid(target_node):
		return
	if agent:
		agent.target_position = target_node.global_position
	var look_target = Vector3(target_node.global_position.x, global_position.y, target_node.global_position.z)
	move_to_target_dir(chase_speed * chase_speed_multiplier, delta, look_target)

func search(delta: float) -> void:
	if agent:
		agent.target_position = last_known_position
		if agent.is_navigation_finished():
			state = State.WANDER
			screech_played = false
			chase_speed_multiplier = 1.0
	move_to_target_dir(speed * chase_speed_multiplier, delta)

func move_to_target_dir(move_speed: float, delta: float, look_target: Vector3 = Vector3.ZERO) -> void:
	if not agent:
		return
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	var final_look_target = look_target
	if final_look_target == Vector3.ZERO:
		final_look_target = global_position + Vector3(dir.x, 0, dir.z)

	rotate_towards_target(final_look_target, delta)

func rotate_towards_target(target_point: Vector3, delta: float) -> void:
	var target_flat = Vector3(target_point.x, global_position.y, target_point.z)
	if global_position.distance_to(target_flat) > 0.1:
		var target_transform = global_transform.looking_at(target_flat, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_transform.basis, rotation_speed * delta).orthonormalized()

func hear_sound(origin: Vector3, volume: float) -> void:
	if state == State.CHASE:
		return
	if is_instance_valid(target_node) and target_node.get("is_inside_building") == true:
		return
	if global_position.distance_to(origin) <= (hear_range * volume):
		last_known_position = origin
		state = State.SEARCH
		if randf() < ENRAGE_CHANCE:
			chase_speed_multiplier = ENRAGE_MULTIPLIER

func apply_knockback(knockback_dir: Vector3, force: float) -> void:
	y_velocity = 10.0
	active_knockback = knockback_dir.normalized() * force

func check_vision() -> bool:
	if not is_instance_valid(target_node) or not vision_ray:
		last_can_see_target = false
		return false

	if target_node.get("is_inside_building") == true:
		last_can_see_target = false
		return false

	if vision_check_cooldown <= 0.0:
		vision_check_cooldown <= VISION_CHECK_INTERVAL
		
		#point the ray directly at target's center or offset pos
		var target_eye_pos = target_node.global_position
		
		#force raycast to look at the targetin global space,
		# bypassing local rot errors on raycast3d node itself
		vision_ray.target_position = vision_ray.to_local(target_eye_pos)
		vision_ray.force_raycast_update()
		
		var collider = vision_ray.get_collider()
		var collider_matches = collider and (collider ==  target_node or collider.is_in_group(target_group))
		last_can_see_target = vision_ray.is_colliding() and collider_matches
	return last_can_see_target

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		y_velocity -= gravity * delta
	else:
		if y_velocity < 0.0:
			y_velocity = 0.0
	velocity.y = y_velocity

func _try_find_target() -> bool:
	if is_instance_valid(target_node):
		return true

	var targets = get_tree().get_nodes_in_group(target_group)
	if targets.size() > 0:
		target_node = targets[0]
		if target_node.has_signal("made_noise") and not target_node.made_noise.is_connected(hear_sound):
			target_node.made_noise.connect(hear_sound)
		return true
	return false

func _on_attack_zone_entered(body: Node3D) -> void:
	if body.is_in_group(target_group):
		var knockback_dir = (body.global_position - global_position).normalized()
		attacked_target.emit(body, attack_damage, knockback_dir, attack_knockback)
		if body.has_method("take_damage"):
			body.take_damage(attack_damage, knockback_dir, attack_knockback)

func _update_sensory_variance(delta: float) -> void:
	sense_timer -= delta
	if sense_timer <= 0:
		sense_timer = sense_shift_interval
		var shift = randf_range(-sense_variance, sense_variance)
		sight_detection_range = max(1.0, base_detection_range + shift)
		hear_range = max(1.0, base_hearing_range + shift)
		if chase_speed_multiplier < ENRAGE_MULTIPLIER:
			chase_speed_multiplier = FAST_CHASE_MULTIPLIER if randf() < FAST_CHASE_CHANCE else 1.0

var ambient_timer := 0.0
func ambient_timer_process(delta: float) -> void:
	ambient_timer -= delta
	if ambient_timer <= 0.0:
		_play_random_ambient_sound()
		_reset_ambient_timer()

func _reset_ambient_timer() -> void:
	ambient_timer = randf_range(ambient_interval_min, ambient_interval_max)

func _play_random_ambient_sound() -> void:
	if ambient_sounds.is_empty() or not ambient_audio_player:
		return
	var sound = ambient_sounds[randi() % ambient_sounds.size()]
	if is_instance_valid(sound):
		ambient_audio_player.stream = sound
		ambient_audio_player.volume_db = randf_range(ambient_volume_min_db, ambient_volume_max_db)
		ambient_audio_player.pitch_scale = randf_range(0.85, 1.15)
		ambient_audio_player.play()
