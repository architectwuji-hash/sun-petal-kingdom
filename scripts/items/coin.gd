extends Area3D
## Coin — pickup item.
## Adds "coin" to the player's inventory.
## Coins are earned ONLY from missions, never from enemies.

func _ready() -> void:
	add_to_group("auto_pickup")
	collision_layer = 4
	collision_mask = 2
	# Visual: gold disc (coin)
	var mesh_inst := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius    = 0.18
	m.bottom_radius = 0.18
	m.height        = 0.06
	mesh_inst.mesh = m
	mesh_inst.rotation_degrees.x = 90.0   # stand on edge
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = Color(1.00, 0.82, 0.0)
	mat.metallic                   = 0.92
	mat.roughness                  = 0.18
	mat.emission_enabled           = true
	mat.emission                   = Color(1.00, 0.78, 0.0)
	mat.emission_energy_multiplier = 0.55
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.40
	add_child(col)
	body_entered.connect(_on_body_entered)
	# Spin tween
	var tween := create_tween().set_loops()
	tween.tween_property(self, "rotation:y", TAU, 1.4)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_item"):
			body.add_item("coin")
		queue_free()
