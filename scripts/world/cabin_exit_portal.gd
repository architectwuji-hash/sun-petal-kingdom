extends Node3D
## Exit portal inside the Cozy Cabin Interior.
## Player presses E to go back to the forest.
## Pattern mirrors auros_temple_return_portal.gd.

@export var label_text: String = "[E] Leave Home"

var _glow_ring: MeshInstance3D = null
var _t: float = 0.0

func _ready() -> void:
	add_to_group("interactable")

	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.2, 0.0)
	lbl.no_depth_test = true
	lbl.modulate = Color(0.6, 1.0, 0.55)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 8
	add_child(lbl)

	# Glowing doormat ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(ring)
	_glow_ring = ring

func interact(player: Node) -> void:
	if not player.has_method("get_save_data"):
		return

	var td: Dictionary = SaveManager.scene_transfer_data
	var return_scene: String = td.get("return_scene", "res://scenes/world/FantasyForest.tscn")

	var pdata: Dictionary = player.get_save_data()
	pdata["x"] = float(td.get("spawn_x", -4.0))
	pdata["y"] = float(td.get("spawn_y", 2.35))
	pdata["z"] = float(td.get("spawn_z", -1.5))
	SaveManager.scene_transfer_data = pdata
	SaveManager.scene_transfer_data["return_scene"] = ""

	get_tree().change_scene_to_file(return_scene)

func _process(delta: float) -> void:
	_t += delta
	if _glow_ring and is_instance_valid(_glow_ring):
		_glow_ring.rotation.y = _t * 1.0
		var pulse: float = 0.7 + 0.3 * sin(_t * 2.5)
		var mat := _glow_ring.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = pulse * 2.5
