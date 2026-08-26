class_name SurgeonLine
extends RefCounted
## 医生线：需求 -> 接收 -> 使用 -> 放中立区 -> 下一件。只跟医生节点打交道。

const ACK_DELAY := 0.4
const GAP_START := 0.8
const GAP_END := 0.15
const USE_MAX := 1.8
const USE_MIN := 0.8
const DEPOSIT_SLIDE := 0.3

var _sys: Node
var _surgeon: Surgeon
var _zone: NeutralZone

var _started := false
var _first_deposit_hint := false
var _full_zone_hint := false


func _init(sys: Node, surgeon: Surgeon, zone: NeutralZone) -> void:
	_sys = sys
	_surgeon = surgeon
	_zone = zone


func on_surgery_start() -> void:
	_started = false
	_first_deposit_hint = false
	_full_zone_hint = false


func on_line_start() -> void:
	## 玩家点了"知道了"，医生开始要第一件。
	if GameState.current_phase != GameState.Phase.SURGERY or _started:
		return
	_started = true
	_schedule(ProcedureData.get_demand_at(0), ACK_DELAY)


func on_deposited(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def == null or not def.discard:
		if not _first_deposit_hint:
			_first_deposit_hint = true
			GameState.hint_changed.emit("用过的器械放中立区了——点击取回归位", false)
	if GameState.current_demand_index < ProcedureData.demand_count():
		_schedule(ProcedureData.get_demand_at(GameState.current_demand_index),
			_gap(GameState.current_demand_index))
	else:
		_surgeon.retract()
		GameState.start_tidy()


func on_zone_freed() -> void:
	if _surgeon != null and _surgeon.hand_waiting():
		_try_deposit()


func on_tidy_start() -> void:
	if not ProcedureData.has_neutral_zone():
		GameState.finish_surgery(false)
		return
	GameState.set_back_table_count(_sys.count_back_table())
	if ProcedureData.has_back_table():
		GameState.hint_changed.emit("收尾:把全部器械归位 back table", false)
	elif _zone == null or _zone.count() == 0:
		GameState.finish_surgery(false)
	else:
		GameState.hint_changed.emit("收尾:清空中立区,器械归位 Mayo", false)


func deliver(inst: Instrument) -> bool:
	## 护士把器械递到医生手里。成功 -> 记分并开始使用流程。
	if _surgeon.try_receive(inst):
		inst.collision_layer = 0
		GameState.set_held(null)
		GameState.record_correct()
		_use_sequence()
		return true
	return false


func schedule_after_return() -> void:
	## S1：器械放回原槽位后，医生才要下一件。
	if GameState.current_demand_index < ProcedureData.demand_count():
		_schedule(ProcedureData.get_demand_at(GameState.current_demand_index),
			_gap(GameState.current_demand_index))
	else:
		GameState.finish_surgery(false)


func _schedule(id: String, delay: float) -> void:
	_sys._deliver_triggered = false
	await Util.wait(delay)
	if GameState.current_phase != GameState.Phase.SURGERY:
		return
	if _surgeon != null and not _surgeon.is_demanding():
		_surgeon.start_demand(id)


func _use_sequence() -> void:
	var duration: float = _use_duration(GameState.current_demand_index)
	await Util.wait(duration)
	if GameState.current_phase != GameState.Phase.SURGERY or _surgeon == null:
		return
	if _surgeon.held_instrument != null and _surgeon.held_instrument.def != null \
			and _surgeon.held_instrument.def.discard:
		_surgeon.discard_held()
		return
	if not ProcedureData.has_neutral_zone():
		_surgeon.return_instrument()
		return
	_surgeon.finish_use()
	await Util.wait(DEPOSIT_SLIDE)
	if GameState.current_phase != GameState.Phase.SURGERY or _surgeon == null:
		return
	_try_deposit()


func _try_deposit() -> void:
	if GameState.current_phase != GameState.Phase.SURGERY or _surgeon == null:
		return
	if not _surgeon.release_to_zone() and not _full_zone_hint:
		_full_zone_hint = true
		GameState.hint_changed.emit("中立区满了——取走一件医生才能继续", false)


func _use_duration(index: int) -> float:
	var total: int = ProcedureData.demand_count()
	if total <= 1:
		return USE_MIN
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return lerpf(USE_MAX, USE_MIN, t)


func _gap(index: int) -> float:
	var total: int = ProcedureData.demand_count()
	if total <= 1:
		return GAP_END
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return lerpf(GAP_START, GAP_END, t)
