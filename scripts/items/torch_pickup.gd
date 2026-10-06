extends Area3D
## TorchPickup — world-placed torch the player can grab.
## Adds "torch" to the player's inventory.

func _ready() -> void:
	add_to_group("auto_pickup")
	collision_layer = 4
	collision_mask = 2

	# ── Visual: wooden handle + flame top ──────────────────────────────────
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.04
	cyl.bottom_radius = 0.05
	cyl.height        = 0.45
	handle.mesh = cyl
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.22, 0.08)
	wood_mat.roughness    = 0.9
	handle.material_override = wood_mat
	handle.position = Vector3(0, 0.0, 0)
	add_child(handle)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	head.mesh = sphere
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color        = Color(1.0, 0.5, 0.05)
	fire_mat.emission_enabled    = true
	fire_mat.emission            = Color(1.0, 0.4, 0.0)
	fire_mat.emission_energy_multiplier = 3.0
	fire_mat.roughness           = 0.6
	head.material_override = fire_mat
	head.position = Vector3(0, 0.28, 0)
	add_child(head)

	# Warm glow from the pickup itself (low range so it doesn't illuminate far)
	var glow := OmniLight3D.new()
	glow.light_color  = Color(1.0, 0.6, 0.2)
	glow.light_energy = 1.4
	glow.omni_range   = 2.5
	glow.position     = Vector3(0, 0.28, 0)
	add_child(glow)

	# Gentle bob tween
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", 0.25, 0.9).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", 0.0,  0.9).set_ease(Tween.EASE_IN_OUT)

	# Collider
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.55
	col.shape  = sph
	add_child(col)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_item"):
			body.add_item("torch")
		queue_free()
