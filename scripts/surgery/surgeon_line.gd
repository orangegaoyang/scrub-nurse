class_name SurgeonLine
extends RefCounted
## 医生线(节拍版)：所有调度由 Conductor 的 4/4 拍网格驱动,不再用秒级延时。
## 每件器械是一个"呼叫-应答"乐句:
##   第 4 拍(强音)医生伸手喊器械 -> 玩家有一小节(WINDOW_BEATS 拍)递送;
##   递上 -> "啪"(按器械类别定音高) -> 医生使用(量化成整拍) -> 放中立区;
##   超时 -> 强音拍上敲手催促,同一个强音重新呼叫。
## 呼叫前一拍手提前抬起(anticipate),强音正好人到手到。
## 难度 = BPM(ProcedureData.tempo()),窗口永远是 WINDOW_BEATS 拍。

const DEPOSIT_SLIDE := 0.3
const USE_BEATS_MAX := 4.0
const USE_BEATS_MIN := 2.0
const SNAP_PITCH := {  # 器械类别 -> 递送"啪"的音高:操作即旋律
	"cutting": 1.2,
	"clamping": 1.05,
	"grasping": 0.95,
	"suturing": 0.9,
	"dressing": 0.85,
}

var _sys: Node
var _surgeon: Surgeon
var _zone: NeutralZone

var _started := false
var _first_deposit_hint := false
var _full_zone_hint := false
var _demand_gen := 0  # 呼叫循环代号:每次新呼叫 +1,旧循环自行失效


func _init(sys: Node, surgeon: Surgeon, zone: NeutralZone) -> void:
	_sys = sys
	_surgeon = surgeon
	_zone = zone


func on_surgery_start() -> void:
	_started = false
	_first_deposit_hint = false
	_full_zone_hint = false
	_demand_gen += 1


func on_line_start() -> void:
	## 玩家点了"知道了"，起拍,医生在第一个强音上要第一件。
	if GameState.current_phase != GameState.Phase.SURGERY or _started:
		return
	_started = true
	Conductor.start(ProcedureData.tempo())
	_schedule(ProcedureData.get_demand_at(0))


func on_deposited(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def == null or not def.discard:
		if not _first_deposit_hint:
			_first_deposit_hint = true
			GameState.hint_changed.emit("用过的器械放中立区了——点击取回归位", false)
	if GameState.current_demand_index < ProcedureData.demand_count():
		_schedule(ProcedureData.get_demand_at(GameState.current_demand_index))
	else:
		_surgeon.retract()
		Conductor.stop()
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
	## 护士把器械递到医生手里。成功 -> "啪"+记分+使用流程(节拍量化)。
	if _surgeon.try_receive(inst):
		inst.collision_layer = 0
		GameState.set_held(null)
		GameState.record_correct()
		Sfx.play_pitched("snap", _snap_pitch(inst.instrument_id))
		_use_sequence()
		return true
	return false


func schedule_after_return() -> void:
	## S1：器械放回原槽位后，医生在下一个强音拍要下一件。
	if GameState.current_demand_index < ProcedureData.demand_count():
		_schedule(ProcedureData.get_demand_at(GameState.current_demand_index))
	else:
		Conductor.stop()
		GameState.finish_surgery(false)


# ---------------- 节拍调度 ----------------

func _schedule(id: String) -> void:
	## 在下一个强音拍(每小节第 4 拍)呼叫 id。新呼叫使旧的呼叫循环失效。
	_sys._deliver_triggered = false
	_demand_gen += 1
	_run_demand(_demand_gen, id)


func _run_demand(gen: int, id: String) -> void:
	## 呼叫循环:强音呼叫 -> 等一小节应答 -> 没递到就在下一个强音重新呼叫。
	var first := true
	while GameState.current_phase == GameState.Phase.SURGERY and gen == _demand_gen:
		if first:
			if not await _wait_to_call(gen):
				return
			first = false
		_surgeon.start_demand(id)
		# 应答窗口:递上后 try_receive 会把医生切出 DEMANDING,循环自然结束。
		for i in Conductor.WINDOW_BEATS:
			await Conductor.beat
			if gen != _demand_gen or GameState.current_phase != GameState.Phase.SURGERY:
				return
			if not _surgeon.is_demanding():
				return
		# 截止(正踩在下一个强音拍上):敲手催促,循环顶部立刻重新呼叫再喊一次。
		_surgeon.impatient_tap()


func _wait_to_call(gen: int) -> bool:
	## 等到下一个强音拍;最后一拍让手提前抬起,强音正好人到手到。
	var n := Conductor.beats_until_call()
	for i in n - 1:
		await Conductor.beat
		if gen != _demand_gen or GameState.current_phase != GameState.Phase.SURGERY:
			return false
	if not Conductor.running:
		return false
	_surgeon.anticipate(Conductor.sec_per_beat())
	await Conductor.beat
	return gen == _demand_gen and GameState.current_phase == GameState.Phase.SURGERY


func _use_sequence() -> void:
	## 使用阶段:时长量化成整拍(越到后面越短),然后弃置/直接归还/放中立区。
	var gen := _demand_gen
	var beats := _use_beats(GameState.current_demand_index)
	for i in beats:
		await Conductor.beat
		if gen != _demand_gen or GameState.current_phase != GameState.Phase.SURGERY:
			return
	if _surgeon == null:
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
	if gen != _demand_gen or GameState.current_phase != GameState.Phase.SURGERY:
		return
	_try_deposit()


func _try_deposit() -> void:
	if GameState.current_phase != GameState.Phase.SURGERY or _surgeon == null:
		return
	if not _surgeon.release_to_zone() and not _full_zone_hint:
		_full_zone_hint = true
		GameState.hint_changed.emit("中立区满了——取走一件医生才能继续", false)


func _snap_pitch(id: String) -> float:
	var def = ProcedureData.get_instrument(id)
	if def == null:
		return 1.0
	return float(SNAP_PITCH.get(def.category, 1.0))


func _use_beats(index: int) -> int:
	var total: int = ProcedureData.demand_count()
	if total <= 1:
		return int(USE_BEATS_MIN)
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return int(round(lerpf(USE_BEATS_MAX, USE_BEATS_MIN, t)))
