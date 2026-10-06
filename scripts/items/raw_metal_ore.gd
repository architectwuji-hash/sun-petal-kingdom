extends Area3D
## RawMetalOre — pickup item.
## Adds "raw_metal_ore" to the player's inventory.
## Produced at the Craft Table (3 Stone → 1 Raw Metal Ore).

func _ready() -> void:
	add_to_group("auto_pickup")
	collision_layer = 4
	collision_mask = 2
	# Visual: rough grey metallic chunk
	var mesh_inst := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.28, 0.18, 0.22)
	mesh_inst.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.40, 0.44)
	mat.metallic      = 0.7
	mat.roughness     = 0.45
	mat.emission_enabled = true
	mat.emission                   = Color(0.55, 0.55, 0.6)
	mat.emission_energy_multiplier = 0.25
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.55
	add_child(col)
	body_entered.connect(_on_body_entered)
	# Small bounce-in tween
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 0.5, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 0.15, 0.18).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_item"):
			body.add_item("raw_metal_ore")
		queue_free()
