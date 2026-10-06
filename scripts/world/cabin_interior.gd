extends Node3D
## Cozy Cabin Interior — perspective camera scene.
## Loaded when the player enters their house from FantasyForest.
## CabinModel (the FBX at 0.01 scale) is instantiated directly in the scene.

## Where the player spawns inside the cabin (just past the door).
const ENTRANCE_POSITION := Vector3(0.0, 0.5, 3.0)

## Camera offset relative to the player — sits inside the cabin and looks inward.
## Y=4 keeps us below most cabin ceilings (cabin is ~3 m at 0.01 scale).
## Negative Z offset pulls the camera behind the player (toward the door).
const CAM_OFFSET   := Vector3(0.0, 4.0, 4.0)
const CAM_PITCH    := -55.0   ## look down-ish without seeing the ceiling from outside

var _camera: Camera3D = null
var _player: Node3D  = null

func _ready() -> void:
	_setup_lighting()
	_setup_camera()
	_setup_collision_floor()
	# Hide ceiling meshes so the interior is always visible from above
	await get_tree().process_frame
	_hide_ceiling()
	_restore_player()

# ---------------------------------------------------------------------------
# Ceiling removal — finds any mesh whose Y centre is above 2.5 m and hides it.
# Tripo cabin interiors at 0.01 scale put ceilings around Y 2.5-3.5.
# ---------------------------------------------------------------------------
func _hide_ceiling() -> void:
	var cabin_model: Node = get_node_or_null("CabinModel")
	if cabin_model == null:
		return
	for mesh: MeshInstance3D in cabin_model.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mesh.get_aabb()
		var world_centre_y: float = mesh.global_position.y + aabb.get_center().y
		if world_centre_y > 2.5:
			mesh.visible = false

# ---------------------------------------------------------------------------
# Collision floor
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
# Lighting — warm cabin feel; strong ambient so model is never dark.
# ---------------------------------------------------------------------------
func _setup_lighting() -> void:
	# Bright ambient fill — ensures mesh is lit even without baked lightmaps
	var ambient := DirectionalLight3D.new()
	ambient.light_color = Color(1.0, 0.95, 0.85)
	ambient.light_energy = 1.2
	ambient.shadow_enabled = false
	ambient.rotation_degrees = Vector3(-70.0, 30.0, 0.0)
	add_child(ambient)

	# Second fill from the front to remove harsh shadows on the player
	var fill_front := DirectionalLight3D.new()
	fill_front.light_color = Color(0.8, 0.85, 1.0)
	fill_front.light_energy = 0.5
	fill_front.shadow_enabled = false
	fill_front.rotation_degrees = Vector3(-30.0, 180.0, 0.0)
	add_child(fill_front)

	# Fireplace warm glow
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
	fill.position = Vector3(0.0, 3.0, 0.0)
	add_child(fill)

# ---------------------------------------------------------------------------
# Camera — perspective, positioned inside the cabin looking down at the floor.
# ---------------------------------------------------------------------------
func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CabinCamera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 65.0
	_camera.near = 0.05
	_camera.far  = 100.0
	_camera.position = ENTRANCE_POSITION + CAM_OFFSET
	_camera.rotation_degrees = Vector3(CAM_PITCH, 0.0, 0.0)
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
# Keep camera behind / above player as they move around the cabin.
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _player == null or _camera == null:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	var pp: Vector3 = _player.global_position
	_camera.global_position = pp + CAM_OFFSET
