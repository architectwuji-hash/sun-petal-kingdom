extends Node3D
## Return portal inside the Auros Temple interior.
## When the player interacts, saves their state and transitions back to the forest.

@export var label_text: String = "[E] Return to Forest 🌿"

func _ready() -> void:
	add_to_group("interactable")

	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 30
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.5, 0.0)
	lbl.no_depth_test = true
	lbl.modulate = Color(0.5, 0.85, 1.0)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 8
	add_child(lbl)

	## Animated glow ring using a simple particle or a rotating mesh
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(0, 0.1, 0)
	add_child(ring)
	_glow_ring = ring

func interact(player: Node) -> void:
	if not player.has_method("get_save_data"):
		return

	var td: Dictionary = SaveManager.scene_transfer_data
	var return_scene: String = td.get("return_scene", "res://scenes/world/FantasyForest.tscn")

	## Preserve inventory/health but place player at the return coords (temple entrance)
	var pdata: Dictionary = player.get_save_data()
	pdata["x"] = float(td.get("spawn_x", 0.0))
	pdata["y"] = float(td.get("spawn_y", 2.35))
	pdata["z"] = float(td.get("spawn_z", 8.0))
	SaveManager.scene_transfer_data = pdata
	SaveManager.scene_transfer_data["return_scene"] = ""  ## clear — we're going home

	get_tree().change_scene_to_file(return_scene)

## Pulsing glow animation
var _glow_ring: MeshInstance3D = null
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _glow_ring and is_instance_valid(_glow_ring):
		_glow_ring.rotation.y = _t * 1.2
		var pulse: float = 0.7 + 0.3 * sin(_t * 3.0)
		var mat := _glow_ring.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = pulse * 3.0
