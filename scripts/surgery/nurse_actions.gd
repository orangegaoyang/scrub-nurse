class_name NurseActions
extends RefCounted
## 护士线：从槽位/中立区/台面拿起器械，放到槽位、Mayo 台面或 back table 分区。

const HOLD_TILT := 15.0
const TRAY_REST_Y := 0.85
const TRAY_HALF_X := 0.30
const TRAY_HALF_Z := 0.235

var _sys: Node
var _player: CharacterBody3D
var _surgeon: Surgeon
var _zone: NeutralZone
var _mayo: Node3D
var _held_parent: Node3D
var _back_zones_parent: Node3D

var _from_zone := false
var _zones_lit := false


func _init(sys: Node, player: CharacterBody3D, surgeon: Surgeon, zone: NeutralZone,
		mayo: Node3D, held_parent: Node3D, back_zones_parent: Node3D) -> void:
	_sys = sys
	_player = player
	_surgeon = surgeon
	_zone = zone
	_mayo = mayo
	_held_parent = held_parent
	_back_zones_parent = back_zones_parent


func on_surgery_start() -> void:
	_zones_lit = false


func note_delivered() -> void:
	_from_zone = false


func pick_up(inst: Instrument) -> void:
	_sys.held_instrument = inst
	_from_zone = inst.state == Instrument.State.IN_ZONE
	var neutral: NeutralZone = null
	var parent: Node = inst.get_parent()
	if parent is TableSlot:
		var slot := parent as TableSlot
		slot.occupied = false
		slot.current_instrument = null
		slot.clear_feedback()
		if slot.category != "":
			GameState.set_back_table_count(count_back_table())
	elif _in_back_zone(inst):
		_get_back_zone(inst).remove_instrument(inst)
		GameState.set_back_table_count(count_back_table())
	elif _in_neutral_zone(inst):
		neutral = _get_neutral_zone(inst)
	inst.set_state(Instrument.State.HELD)
	inst.reparent(_held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(HOLD_TILT, 0.0, 0.0)
	_sys._deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	if neutral != null:
		neutral.collected()
	_emit_return_hint()


func take_back(inst: Instrument) -> void:
	## S1：从医生还回来的手里接走用过的器械。
	_sys.held_instrument = inst
	_surgeon.take_back()
	inst.set_state(Instrument.State.HELD)
	inst.reparent(_held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(HOLD_TILT, 0.0, 0.0)
	_sys._deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	GameState.hint_changed.emit("放回 Mayo 原槽位", false)


func place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = _sys.held_instrument
	if slot.can_accept(inst):
		_sys.held_instrument = null
		inst.set_state(Instrument.State.IN_SLOT)
		inst.reparent(slot)
		inst.transform = Transform3D.IDENTITY
		inst.position = Vector3(0, 0.01, 0)
		inst.collision_layer = 1
		slot.occupied = true
		slot.current_instrument = inst
		slot.set_feedback(true)
		GameState.set_held(null)
		Sfx.play("slot_correct")
		GameState.hint_changed.emit("", false)
		if GameState.current_phase == GameState.Phase.SURGERY:
			_sys.schedule_after_return()
	else:
		slot.set_feedback(false)
		inst.play_reject()
		Sfx.play("slot_wrong")


func place_on_mayo(point: Vector3) -> void:
	var inst: Instrument = _sys.held_instrument
	_sys.held_instrument = null
	inst.set_state(Instrument.State.ON_MAYO)
	inst.reparent(_mayo)
	var local := _mayo.to_local(point)
	local.x = clampf(local.x, -TRAY_HALF_X, TRAY_HALF_X)
	local.z = clampf(local.z, -TRAY_HALF_Z, TRAY_HALF_Z)
	local.y = TRAY_REST_Y
	inst.position = local
	inst.rotation_degrees = Vector3.ZERO
	inst.collision_layer = 1
	inst.freeze = true
	GameState.set_held(null)
	Sfx.play("slot_correct")
	GameState.hint_changed.emit("", false)
	_from_zone = false
	if GameState.current_phase == GameState.Phase.TIDY and (_zone == null or _zone.count() == 0):
		GameState.finish_surgery(false)


func place_in_zone(bzone: BackZone) -> void:
	var inst: Instrument = _sys.held_instrument
	if bzone.can_accept(inst) and not bzone.is_full():
		_sys.held_instrument = null
		bzone.place_instrument(inst)
		inst.collision_layer = 1
		bzone.set_feedback(true)
		GameState.set_held(null)
		Sfx.play("slot_correct")
		GameState.hint_changed.emit("", false)
		_from_zone = false
		GameState.set_back_table_count(count_back_table())
		if not _zones_lit:
			_zones_lit = true
			for c in _back_zones_parent.get_children():
				if c is BackZone:
					(c as BackZone).set_dimmed(false)
	else:
		bzone.set_feedback(false)
		inst.play_reject()
		Sfx.play("slot_wrong")


func count_back_table() -> int:
	var n: int = GameState.discarded_count
	if _back_zones_parent == null:
		return n
	for c in _back_zones_parent.get_children():
		if c is BackZone:
			n += (c as BackZone).current_instruments.size()
	return n


func _emit_return_hint() -> void:
	if not _from_zone or _sys.held_instrument == null:
		GameState.hint_changed.emit("", false)
		return
	var id: String = _sys.held_instrument.instrument_id
	var def = ProcedureData.get_instrument(id)
	if not ProcedureData.has_back_table():
		GameState.hint_changed.emit("%s 放回 Mayo 台面" % def.name_cn, false)
		return
	var remaining: int = ProcedureData.remaining_uses(id, GameState.current_demand_index)
	if remaining > 0:
		GameState.hint_changed.emit("%s 还剩 %d 次 → 放回 Mayo 台面" % [def.name_cn, remaining], false)
	else:
		GameState.hint_changed.emit("%s 用完 → 放回 back table(按 Q)" % def.name_cn, false)


func _in_back_zone(inst: Instrument) -> bool:
	return Util.find_ancestor(inst.get_parent(), BackZone) != null


func _get_back_zone(inst: Instrument) -> BackZone:
	return Util.find_ancestor(inst.get_parent(), BackZone)


func _in_neutral_zone(inst: Instrument) -> bool:
	return Util.find_ancestor(inst.get_parent(), NeutralZone) != null


func _get_neutral_zone(inst: Instrument) -> NeutralZone:
	return Util.find_ancestor(inst.get_parent(), NeutralZone)
