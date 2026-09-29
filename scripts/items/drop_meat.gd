extends Area3D


func _ready() -> void:
	add_to_group("auto_pickup")
	collision_layer = 4
	collision_mask = 2
	var meat_scene: PackedScene = load("res://assets/models/items/kenney_food/meat-cooked.glb")
	if meat_scene:
		var mesh_inst := meat_scene.instantiate()
		mesh_inst.scale = Vector3(1.5, 1.5, 1.5)
		add_child(mesh_inst)
	else:
		var mesh_inst := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.3, 0.2, 0.4)
		mesh_inst.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.18, 0.18)
		mesh_inst.material_override = mat
		add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.5
	add_child(col)
	body_entered.connect(_on_body_entered)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 0.6, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 0.15, 0.2).set_ease(Tween.EASE_IN)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_item"):
			body.add_item("meat")
		queue_free()
