class_name InstrumentSpawner
extends RefCounted
## 准备阶段：把器械在 back table 台面上整齐平铺开；多件备用的直接摆上 Mayo 托盘。

const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

## 器械统一朝向：绕 Y 转 90°（竖着摆）。模型长轴沿本地 Z，转 90° 后长轴落到
## 世界 X 轴——所以横向占位要用 size.z。
const ROT_Y := 90.0
## 在这基础朝向附近加一点随机转角（±度），让每件略微朝向不同，像手摆的而非
## 完全平行。JITTER 越小越整齐，想彻底平行就设 0。
const ROT_JITTER_DEG := 12.0
## 每行横向铺到 ±ROW_HALF（台面半宽附近），超了就换下一行。
const ROW_HALF := 0.35
## 件与件之间的留白，防止相邻模型边缘贴死。
const ROW_GAP := 0.05
## 换行时往纵深让的距离。若两行前后方向压到，把它调大即可。
const ROW_DEPTH := 0.22
## 器械统一下沉的高度（相对 BackTableInstruments 节点，其已在台面高度）。
const LAYOUT_Y := 0.01

var _instruments_parent: Node3D


func _init(instruments_parent: Node3D) -> void:
	_instruments_parent = instruments_parent


func spawn() -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 1.0

	# 展平实例列表；shuffle 只决定"哪件摆哪个位置"，不影响整齐度。
	var ids: Array[String] = ProcedureData.instrument_order.duplicate()
	ids.shuffle()

	# 从左到右一件件铺：每件按它自己的长度接在前一件后面，天然不重叠；
	# 一行放不下就换下一行（往纵深让 ROW_DEPTH）。所有器械统一朝向 ROT_Y。
	var x := -ROW_HALF
	var z := 0.0
	var row := 0
	var max_row := 0
	var insts: Array[RigidBody3D] = []

	for id in ids:
		var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
		_instruments_parent.add_child(inst)
		inst.setup(id)
		inst.rotation_degrees = Vector3(0, ROT_Y + randf_range(-ROT_JITTER_DEG, ROT_JITTER_DEG), 0)
		var w: float = _footprint(inst).z   # 转 90° 后，横向占位 = 本地 Z（长轴）
		if x + w > ROW_HALF:
			x = -ROW_HALF
			z -= ROW_DEPTH
			row += 1
		max_row = maxi(max_row, row)
		inst.position = Vector3(x + w * 0.5, LAYOUT_Y, z)
		inst.physics_material_override = mat
		inst.set_state(Instrument.State.IN_TRAY)
		inst.collision_layer = 1
		inst.freeze = true
		x += w + ROW_GAP
		insts.append(inst)

	# 把整块沿 +Z 平移“行占地的一半”，让各行对称落在台面里——否则最上面那行会
	# 整行拱到台边外面。行从 z=0 往下堆，最顶行 = -max_row·ROW_DEPTH，居中即平移
	# 一半行高（max_row·ROW_DEPTH / 2）。
	var shift := (max_row * 0.5) * ROW_DEPTH
	for inst in insts:
		inst.position.z += shift

	await Util.wait(0.3)


func _footprint(inst: RigidBody3D) -> Vector3:
	## 器械真实尺寸：setup 时碰撞盒已被拟合成模型包围盒，直接读取即可。
	var col: CollisionShape3D = inst.get_node_or_null("CollisionShape3D")
	if col != null and col.shape is BoxShape3D:
		return (col.shape as BoxShape3D).size
	return Vector3(0.12, 0.04, 0.25)
