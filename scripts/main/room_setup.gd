class_name RoomSetup
extends RefCounted
## 运行时适配导入的房间：清掉单独导出的烘焙偏移、降床、材质双面渲染。

const BED_CENTER := Vector3(0.39, 0.2, 0.225)
const BED_SCALE := Vector3(1.0, 0.8, 1.0)


static func apply(room: Node3D, back_table_visual: Node3D) -> void:
	# back table 单独导出时带了一段烘焙偏移，清掉；位置由场景节点决定。
	var bt := back_table_visual.get_node_or_null("backtable") as Node3D
	if bt != null:
		bt.position = Vector3.ZERO
	# 床绕底座降下，让 Mayo 托盘高过床垫。
	var bed := room.get_node("bed") as Node3D
	var bed_pivot := Node3D.new()
	bed_pivot.name = "BedPivot"
	room.add_child(bed_pivot)
	bed_pivot.position = BED_CENTER
	bed.reparent(bed_pivot)
	bed.position = -BED_CENTER
	bed.scale = BED_SCALE
	_double_side(room)
	_double_side(back_table_visual)


static func _double_side(node: Node3D) -> void:
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(i)
				if mat == null:
					mat = mi.mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var dup := (mat as BaseMaterial3D).duplicate()
					dup.cull_mode = BaseMaterial3D.CULL_DISABLED
					mi.set_surface_override_material(i, dup)
		if c is Node3D:
			_double_side(c)
