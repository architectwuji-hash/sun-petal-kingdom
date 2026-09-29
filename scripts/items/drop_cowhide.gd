extends Area3D

var _label_hint: Label3D = null


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 2
	var mesh_inst := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.5, 0.05, 0.4)
	mesh_inst.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.28, 0.12)
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.6
	add_child(col)
	_label_hint = Label3D.new()
	_label_hint.text = "[E] Pick up Cow Hide"
	_label_hint.position = Vector3(0, 1.0, 0)
	_label_hint.pixel_size = 0.006
	_label_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_hint.visible = false
	add_child(_label_hint)
	body_entered.connect(func(b): if b.is_in_group("player"): _label_hint.visible = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _label_hint.visible = false)


func interact(player: Node3D) -> void:
	if player.has_method("add_item"):
		player.add_item("cowhide")
	queue_free()
