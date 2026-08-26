class_name MayoLayout
extends RefCounted
## Mayo 槽位与 back table 的可见性策略（按术式/阶段切换）。

var _slots_parent: Node3D
var _back_table: Node3D
var _back_zones_parent: Node3D
var _mayo: Node3D


func _init(slots_parent: Node3D, back_table: Node3D, back_zones_parent: Node3D,
		mayo: Node3D) -> void:
	_slots_parent = slots_parent
	_back_table = back_table
	_back_zones_parent = back_zones_parent
	_mayo = mayo


func apply_guidance_tier() -> void:
	## 准备阶段按器械数量显示槽位；手术中只有 S1（槽位归还）保留。
	var count: int = ProcedureData.instrument_order.size()
	var in_surgery: bool = GameState.current_phase == GameState.Phase.SURGERY \
		or GameState.current_phase == GameState.Phase.TIDY
	var show: bool = not in_surgery or not ProcedureData.surgery_free_mayo()
	for s in _slots_parent.get_children():
		if s is TableSlot:
			var active: bool = show and (s as TableSlot).slot_index < count
			(s as TableSlot).visible = active
			(s as TableSlot).collision_layer = 2 if active else 0


func apply_back_table_visibility() -> void:
	var phase: int = GameState.current_phase
	var in_prep: bool = phase == GameState.Phase.PREP or phase == GameState.Phase.COUNTDOWN
	_back_table.visible = in_prep or ProcedureData.has_back_table()
	_back_zones_parent.visible = ProcedureData.has_back_table()


func release_slot_instruments() -> void:
	## 自由 Mayo 术式：把准备时排好的器械从槽位放平到台面上。
	if not ProcedureData.surgery_free_mayo():
		return
	for s in _slots_parent.get_children():
		if s is TableSlot and s.occupied:
			var inst: Instrument = s.current_instrument
			var gp: Vector3 = inst.global_position
			s.occupied = false
			s.current_instrument = null
			s.clear_feedback()
			inst.set_state(Instrument.State.ON_MAYO)
			inst.reparent(_mayo)
			var local := _mayo.to_local(gp)
			local.y = 0.85
			inst.position = local
			inst.rotation_degrees = Vector3.ZERO
			inst.collision_layer = 1
			inst.freeze = true
