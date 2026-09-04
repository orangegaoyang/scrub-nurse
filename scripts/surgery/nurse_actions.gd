class_name NurseActions
extends RefCounted
## 护士线：从槽位/中立区/台面拿起器械，放到槽位、Mayo 台面或 back table 分区。
## 机械操作(状态/reparent/碰撞/姿态)走 InstrumentOps;这里只管护士侧的
## 出处记录、取消、提示与流程推进。

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

# 右键取消：记录拿起前的出处（槽位/分区锚点/中立区锚点/mayo），cancel 时放回。
var _pickup_origin: Node = null
var _pickup_local := Vector3.ZERO
var _pickup_rot := Vector3.ZERO


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
	_pickup_origin = inst.get_parent()
	_pickup_local = inst.position
	_pickup_rot = inst.rotation_degrees
	var neutral: NeutralZone = null
	var parent: Node = inst.get_parent()
	if parent is TableSlot:
		var slot := parent as TableSlot
		slot.occupied = false
		slot.current_instrument = null
		slot.clear_feedback()
	elif _in_back_zone(inst):
		_get_back_zone(inst).remove_instrument(inst)
	elif _in_neutral_zone(inst):
		neutral = _get_neutral_zone(inst)
	InstrumentOps.attach_to_hand(inst, _held_parent, InstrumentOps.HOLD_TILT_SURGERY)
	_sys._deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	if neutral != null:
		neutral.collected()
	_emit_return_hint()


func take_back(inst: Instrument) -> void:
	## S1：从医生还回来的手里接走用过的器械。
	_sys.held_instrument = inst
	_pickup_origin = null  # 接回手里的器械不参与右键取消——必须归位
	_surgeon.take_back()
	InstrumentOps.attach_to_hand(inst, _held_parent, InstrumentOps.HOLD_TILT_SURGERY)
	_sys._deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	GameState.hint_changed.emit("放回 Mayo 原槽位", false)


func cancel() -> void:
	## 右键取消：把器械放回拿起前的位置，不带任何放置副作用（不推进医生线、
	## 不计分）。接回医生手里的器械（take_back）不可取消。
	var inst: Instrument = _sys.held_instrument
	if inst == null or _pickup_origin == null or not is_instance_valid(_pickup_origin):
		return
	_sys.held_instrument = null
	var origin: Node = _pickup_origin
	_pickup_origin = null
	if origin is TableSlot:
		InstrumentOps.seat_in_slot(inst, origin as TableSlot)
	elif Util.find_ancestor(origin, BackZone) != null:
		var bzone := Util.find_ancestor(origin, BackZone) as BackZone
		InstrumentOps.seat_in_back_zone(inst, bzone)
	elif Util.find_ancestor(origin, NeutralZone) != null:
		var zone := Util.find_ancestor(origin, NeutralZone) as NeutralZone
		if zone.call("place_instrument", inst) == null:
			# 医生已经占掉了空出来的锚点——退而求其次放回 Mayo 台面。
			InstrumentOps.rest_on_mayo(inst, _mayo, Vector3(0, TRAY_REST_Y, 0))
	else:
		# 从 Mayo 台面拿的：回到托盘上原来的位置。
		InstrumentOps.put_back(inst, origin, Instrument.State.ON_MAYO)
		inst.position = _pickup_local
		inst.rotation_degrees = _pickup_rot
	_from_zone = false
	GameState.set_held(null)
	GameState.hint_changed.emit("", false)
	Sfx.play("instrument_pick")


func place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = _sys.held_instrument
	if slot.can_accept(inst):
		_sys.held_instrument = null
		InstrumentOps.seat_in_slot(inst, slot)
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
	var local := _mayo.to_local(point)
	local.x = clampf(local.x, -TRAY_HALF_X, TRAY_HALF_X)
	local.z = clampf(local.z, -TRAY_HALF_Z, TRAY_HALF_Z)
	local.y = TRAY_REST_Y
	InstrumentOps.rest_on_mayo(inst, _mayo, local)
	GameState.set_held(null)
	Sfx.play("slot_correct")
	GameState.hint_changed.emit("", false)
	_from_zone = false


func place_in_zone(bzone: BackZone) -> void:
	var inst: Instrument = _sys.held_instrument
	if bzone.can_accept(inst) and not bzone.is_full():
		_sys.held_instrument = null
		InstrumentOps.seat_in_back_zone(inst, bzone)
		bzone.set_feedback(true)
		GameState.set_held(null)
		Sfx.play("slot_correct")
		GameState.hint_changed.emit("", false)
		_from_zone = false
		if not _zones_lit:
			_zones_lit = true
			for c in _back_zones_parent.get_children():
				if c is BackZone:
					(c as BackZone).set_dimmed(false)
	else:
		bzone.set_feedback(false)
		inst.play_reject()
		Sfx.play("slot_wrong")


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
