## fbx_collision.gd
## Attach to any FBX/GLB building node to auto-generate a single AABB box
## collision at runtime. Much faster than per-mesh trimesh collision.
extends Node3D

func _ready() -> void:
	# Wait one frame so the imported scene tree is fully set up
	await get_tree().process_frame
	_add_box_collision()

func _add_box_collision() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	if meshes.is_empty():
		return

	## Compute a combined AABB in this node's local space
	var root_inv: Transform3D = global_transform.affine_inverse()
	var combined: AABB = AABB()
	var first := true
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var local_xform: Transform3D = root_inv * mi.global_transform
		var local_aabb: AABB         = local_xform * mi.get_aabb()
		if first:
			combined = local_aabb
			first    = false
		else:
			combined = combined.merge(local_aabb)

	if first:
		return  # no valid meshes

	## Single StaticBody3D + BoxShape3D covering the whole building
	var body := StaticBody3D.new()
	body.name = "BuildingCollision"
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size    = combined.size + Vector3(0.1, 0.1, 0.1)
	col.shape   = box
	col.position = combined.get_center()
	body.add_child(col)
	add_child(body)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, out)
