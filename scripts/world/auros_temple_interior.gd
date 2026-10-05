extends Node3D

## Auros Temple Interior — loads the 3D model asset and restores player state from SaveManager.

const MODEL_PATH := "res://assets/models/buildings/auros_temple_interior/auros_temple_interior.fbx"

## Where the player appears when entering the temple.
## Adjust once you've inspected the model in-editor to find a good walkable spot.
const ENTRANCE_POSITION := Vector3(0.0, 0.5, 5.0)

func _ready() -> void:
	_load_model()
	_setup_lighting()
	await get_tree().process_frame
	_restore_player()

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
func _load_model() -> void:
	var packed = load(MODEL_PATH)
	if packed == null:
		push_warning("AurosTempleInterior: model not found — using placeholder geometry.")
		_build_placeholder()
		return
	var model: Node3D = packed.instantiate()
	# FBX units from Tripo are in centimetres → scale to metres.
	# Adjust this if the model comes out too large or too small in-editor.
	model.scale = Vector3(0.01, 0.01, 0.01)
	model.name = "TempleModel"
	add_child(model)

func _build_placeholder() -> void:
	# Simple box-room so the scene isn't completely empty if the FBX hasn't
	# been imported by Godot Editor yet.
	var floor_inst := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(40.0, 0.4, 50.0)
	floor_inst.mesh = floor_mesh
	var floor_col := StaticBody3D.new()
	var floor_col_shape := CollisionShape3D.new()
	floor_col_shape.shape = BoxShape3D.new()
	(floor_col_shape.shape as BoxShape3D).size = Vector3(40.0, 0.4, 50.0)
	floor_col.add_child(floor_col_shape)
	floor_col.position.y = -0.2
	add_child(floor_col)
	floor_inst.position.y = -0.2
	add_child(floor_inst)

	# Ceiling
	var ceil_inst := MeshInstance3D.new()
	var ceil_mesh := BoxMesh.new()
	ceil_mesh.size = Vector3(40.0, 0.4, 50.0)
	ceil_inst.mesh = ceil_mesh
	ceil_inst.position.y = 14.4
	add_child(ceil_inst)

# ---------------------------------------------------------------------------
# Lighting
# ---------------------------------------------------------------------------
func _setup_lighting() -> void:
	# Warm directional sun shaft from above
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.7)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	add_child(sun)

	# Ambient fill — soft golden glow throughout hall
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.5)
	fill.light_energy = 1.5
	fill.omni_range = 30.0
	fill.position = Vector3(0.0, 8.0, 0.0)
	add_child(fill)

	# Two entrance torches
	for sx in [-4.0, 4.0]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.6, 0.2)
		torch.light_energy = 2.0
		torch.omni_range = 8.0
		torch.position = Vector3(sx, 2.5, 18.0)
		add_child(torch)

	# Altar spotlight deep in the room
	var altar_light := OmniLight3D.new()
	altar_light.light_color = Color(1.0, 0.95, 0.6)
	altar_light.light_energy = 3.0
	altar_light.omni_range = 12.0
	altar_light.position = Vector3(0.0, 5.0, -10.0)
	add_child(altar_light)

# ---------------------------------------------------------------------------
# Player restore
# ---------------------------------------------------------------------------
func _restore_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("AurosTempleInterior: player node not found.")
		return

	var td: Dictionary = SaveManager.scene_transfer_data
	if td.is_empty():
		# No transfer data — just place at entrance (e.g., testing directly)
		player.global_position = ENTRANCE_POSITION
		return

	var restore: Dictionary = td.duplicate()
	# Override position to entrance regardless of what was stored
	restore["x"] = ENTRANCE_POSITION.x
	restore["y"] = ENTRANCE_POSITION.y
	restore["z"] = ENTRANCE_POSITION.z

	if player.has_method("apply_save_data"):
		player.apply_save_data(restore)
	else:
		player.global_position = ENTRANCE_POSITION
