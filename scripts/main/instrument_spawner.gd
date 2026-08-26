class_name InstrumentSpawner
extends RefCounted
## 准备阶段：把器械撒在 back table 上；多件备用的直接摆上 Mayo 托盘。

const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

var _instruments_parent: Node3D
var _mayo: Node3D


func _init(instruments_parent: Node3D, mayo: Node3D) -> void:
	_instruments_parent = instruments_parent
	_mayo = mayo


func spawn() -> void:
	var ids: Array = ProcedureData.instrument_order.duplicate()
	ids.shuffle()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 1.0
	for id in ids:
		var def = ProcedureData.get_instrument(id)
		var count: int = def.count if def != null else 1
		for k in count:
			var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
			if k == 0:
				_instruments_parent.add_child(inst)
				inst.position = Vector3(
					randf_range(-0.45, 0.45),
					0.04 + randf_range(0.0, 0.04),
					randf_range(-0.22, 0.22))
				inst.setup(id)
				inst.rotation_degrees = Vector3(0, randf_range(0.0, 360.0), 0)
				inst.physics_material_override = mat
				_lock_for_drop(inst)
				inst.freeze = false
			else:
				_mayo.add_child(inst)
				inst.position = _spare_spot(k)
				inst.setup(id)
				inst.rotation_degrees = Vector3.ZERO
				inst.set_state(Instrument.State.ON_MAYO)
				inst.collision_layer = 1
				inst.freeze = true
	await Util.wait(0.5)
	for inst in _instruments_parent.get_children():
		if inst is Instrument:
			inst.freeze = true
			_unlock_drop(inst)


func _spare_spot(k: int) -> Vector3:
	var start_x := -0.22
	var step_x := 0.10
	return Vector3(start_x + step_x * (k - 1), 0.85, -0.16)


func _lock_for_drop(inst: RigidBody3D) -> void:
	inst.axis_lock_linear_x = true
	inst.axis_lock_linear_z = true
	inst.axis_lock_angular_x = true
	inst.axis_lock_angular_y = true
	inst.axis_lock_angular_z = true


func _unlock_drop(inst: RigidBody3D) -> void:
	inst.axis_lock_linear_x = false
	inst.axis_lock_linear_z = false
	inst.axis_lock_angular_x = false
	inst.axis_lock_angular_y = false
	inst.axis_lock_angular_z = false
