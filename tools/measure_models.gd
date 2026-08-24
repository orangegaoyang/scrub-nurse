extends SceneTree
## Headless helper: print world-space AABBs of the key models so scene
## placement (back table, neutral zone, mayo) can be grounded in real sizes.
## Transforms are composed manually (global_transform is unavailable in
## --script mode). Run:
##   godot --headless --path . --script res://tools/measure_models.gd


func _init() -> void:
	var paths := [
		"res://assets/models/back_table.glb",
		"res://assets/models/surgery/small_backtable.glb",
		"res://assets/models/surgery/small_mayo.glb",
		"res://assets/models/hand.glb",
	]
	for path in paths:
		var res := load(path)
		if res == null:
			print("LOAD FAILED: ", path)
			continue
		var node: Node3D = res.instantiate()
		var aabb := _collect(node, Transform3D.IDENTITY)
		if aabb.size.length() <= 0.0001:
			print(path, " -> no meshes")
		else:
			print("%s -> pos=%s size=%s center=%s" % [path, aabb.position, aabb.size, aabb.get_center()])
		node.free()
	quit()


func _collect(n: Node, parent_xform: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var self_xform := Transform3D.IDENTITY
	if n is Node3D:
		self_xform = parent_xform * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var m := mi.mesh.get_aabb()
			if m.size.length() > 0.0001:
				result = self_xform * m
				has = true
	for c in n.get_children():
		var child_aabb := _collect(c, self_xform)
		if child_aabb.size.length() > 0.0001:
			if has:
				result = result.merge(child_aabb)
			else:
				result = child_aabb
				has = true
	return result
