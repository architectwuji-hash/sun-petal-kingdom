## tree_platform.gd
## StaticBody3D placed at the canopy of a tree.
## Players with tree running can land here and use it as a launchpad.
## Shows a visible semi-transparent glowing platform so the player can see it.
##
## Add as a child StaticBody3D inside KenneyTreeHigh.tscn / KenneyTree.tscn.
extends StaticBody3D

var _glow:    OmniLight3D   = null
var _mesh:    MeshInstance3D = null
var _tween:   Tween          = null

func _ready() -> void:
	add_to_group("tree_platform")
	_build_platform_mesh()
	_build_glow()

func _build_platform_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 2.0   # large enough to land on easily
	cyl.bottom_radius = 2.0
	cyl.height        = 0.15
	cyl.radial_segments = 16
	_mesh.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color      = Color(0.25, 0.95, 0.35, 0.50)  # translucent green
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled  = true
	mat.emission          = Color(0.2, 0.85, 0.25)
	mat.emission_energy   = 0.4
	mat.cull_mode         = BaseMaterial3D.CULL_DISABLED     # visible from below too
	_mesh.material_override = mat

	add_child(_mesh)

func _build_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.light_color      = Color(0.55, 1.0, 0.3)   # soft forest green-gold
	_glow.light_energy     = 0.0                       # off by default
	_glow.omni_range       = 5.0
	_glow.omni_attenuation = 1.5
	_glow.shadow_enabled   = false
	add_child(_glow)

## Call from tree_running.gd to toggle the targeting glow.
func set_targeted(on: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUAD)
	var target_energy: float = 1.8 if on else 0.0
	_tween.tween_property(_glow, "light_energy", target_energy, 0.25)
