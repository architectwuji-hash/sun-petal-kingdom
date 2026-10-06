extends Node3D
## Cozy Cabin Interior -- top-down camera scene.
## Loaded when the player enters their house from FantasyForest.
## CabinModel (the FBX) is instantiated directly in the scene.

## Where the player appears inside the cabin (just past the door).
const ENTRANCE_POSITION := Vector3(0.0, 0.5, 3.0)

## Top-down camera height and angle
const CAM_HEIGHT    := 14.0
const CAM_PITCH_DEG := -90.0

var _camera: Camera3D = null
var _player: Node3D  = null

func _ready() -> void:
	_setup_lighting()
	_setup_camera()
	_setup_collision_floor()
	await get_tree().process_frame
	_restore_player()

# ---------------------------------------------------------------------------
# Collision floor (so the player doesn't fall through the FBX)
# ---------------------------------------------------------------------------
func _setup_collision_floor() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(16.0, 0.5, 16.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.05, 0.0)
	sb.name = "FloorCollider"
	add_child(sb)

# ---------------------------------------------------------------------------
# Lighting  -- warm cabin feel
# ---------------------------------------------------------------------------
func _setup_lighting() -> void:
	# Soft ambient from above
	var ambient := DirectionalLight3D.new()
	ambient.light_color = Color(1.0, 0.9, 0.75)
	ambient.light_energy = 0.6
	ambient.shadow_enabled = false
	ambient.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
	add_child(ambient)

	# Fireplace warm glow (left side, typical cabin layout)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.5, 0.15)
	fire.light_energy = 3.0
	fire.omni_range = 10.0
	fire.position = Vector3(-3.0, 1.0, -3.0)
	add_child(fire)

	# Ceiling candle fill
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.55)
	fill.light_energy = 1.4
	fill.omni_range = 14.0
	fill.position = Vector3(0.0, 6.0, 0.0)
	add_child(fill)

# ---------------------------------------------------------------------------
# Camera  -- top-down orthogonal view
# ---------------------------------------------------------------------------
func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "TopDownCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 11.0         # how many metres are visible across the screen
	_camera.near = 0.1
	_camera.far  = 200.0
	_camera.position = Vector3(0.0, CAM_HEIGHT, 0.0)
	_camera.rotation_degrees = Vector3(CAM_PITCH_DEG, 0.0, 0.0)
	_camera.make_current()
	add_child(_camera)


# ---------------------------------------------------------------------------
# Player restore
# ---------------------------------------------------------------------------
func _restore_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("CabinInterior: player not found.")
		return

	var td: Dictionary = SaveManager.scene_transfer_data
	if td.is_empty():
		_player.global_position = ENTRANCE_POSITION
	else:
		var restore: Dictionary = td.duplicate()
		restore["x"] = ENTRANCE_POSITION.x
		restore["y"] = ENTRANCE_POSITION.y
		restore["z"] = ENTRANCE_POSITION.z
		if _player.has_method("apply_save_data"):
			_player.apply_save_data(restore)
		else:
			_player.global_position = ENTRANCE_POSITION

# ---------------------------------------------------------------------------
# Keep camera centred above player while inside
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _player == null or _camera == null:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	var px: float = _player.global_position.x
	var pz: float = _player.global_position.z
	_camera.global_position = Vector3(px, CAM_HEIGHT, pz)
