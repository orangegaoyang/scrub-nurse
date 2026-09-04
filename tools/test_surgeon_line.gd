extends Node
## Headless check: SurgeonLine 节拍化全流程。
## 假医生/假器械(继承真类以满足类型签名) + 真 Conductor(240bpm) 跑完 S1 全部需求:
## 呼叫顺序 = demand_sequence;一次故意超时要触发敲手催促+重新呼叫;
## 全部递完进入 RESULT(直接结算) 且收拍。
## Run: godot --headless res://tools/test_surgeon_line.tscn

var _line: SurgeonLine
var _surgeon: FakeSurgeon
var _sys := FakeSys.new()
var _done := false
var _fail := ""


class FakeSys extends Node:
	var _deliver_triggered := false


class FakeInst extends Instrument:
	func _init(p_id: String, p_def: Variant) -> void:
		instrument_id = p_id
		def = p_def


class FakeSurgeon extends Surgeon:
	var demand_calls: Array[String] = []
	var taps := 0
	var anticipates := 0

	func is_demanding() -> bool:
		return state == State.DEMANDING

	func start_demand(id: String) -> void:
		demand_calls.append(id)
		current_demand_id = id
		state = State.DEMANDING
		held_instrument = null

	func try_receive(inst: Instrument) -> bool:
		if state != State.DEMANDING:
			return false
		if inst.instrument_id == current_demand_id:
			held_instrument = inst
			state = State.USING
			return true
		return false

	func anticipate(_duration: float) -> void:
		anticipates += 1

	func impatient_tap() -> void:
		taps += 1

	func retract() -> void:
		state = State.IDLE
		held_instrument = null

	func discard_held() -> void:
		var id := held_instrument.instrument_id
		held_instrument = null
		state = State.IDLE
		instrument_deposited.emit(id)

	func return_instrument() -> void:
		state = State.RETURNING


func _ready() -> void:
	ProcedureData._load_procedure("res://data/procedure_1.json")
	GameState.reset()
	GameState.current_phase = GameState.Phase.SURGERY
	_surgeon = FakeSurgeon.new()
	_line = SurgeonLine.new(_sys, _surgeon, null)
	_surgeon.instrument_deposited.connect(_line.on_deposited)
	_line.on_line_start()
	_drive()


func _drive() -> void:
	var seq: Array[String] = ProcedureData.demand_sequence
	var deliver_next := false  # 首件第一次呼叫期间故意不递,验证敲手催促+重新呼叫
	var was_returning := false
	var deadline := Time.get_ticks_msec() + 40000
	while not _done and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.03).timeout
		match GameState.current_phase:
			GameState.Phase.RESULT:
				_done = true
			GameState.Phase.SURGERY:
				if _surgeon.state == Surgeon.State.RETURNING:
					# 护士接回+放回槽位 -> 医生才要下一件(S1)。只触发一次。
					if not was_returning:
						was_returning = true
						_line.schedule_after_return()
				else:
					was_returning = false
					if _surgeon.is_demanding():
						var idx := GameState.current_demand_index
						if idx >= seq.size():
							continue
						if not deliver_next and _surgeon.demand_calls.size() < 2:
							continue  # 首件首次呼叫:耗完窗口,等催促重呼
						deliver_next = true
						_line.deliver(FakeInst.new(seq[idx], ProcedureData.get_instrument(seq[idx])))
	# 断言
	if not _done:
		_fail = "超时未进入 RESULT"
	if _surgeon.taps < 1:
		_fail += " | 没有触发超时催促"
	# 首件被故意拖超时一次:期望序列 = 首件呼叫两次,其余按序
	var expected: Array[String] = [seq[0], seq[0]]
	for i in range(1, seq.size()):
		expected.append(seq[i])
	if _surgeon.demand_calls != expected:
		_fail += " | 呼叫序列异常: %s" % [_surgeon.demand_calls]
	print("demand_calls=", _surgeon.demand_calls, " taps=", _surgeon.taps,
			" anticipates=", _surgeon.anticipates,
			" correct=", GameState.surgery_correct, " wrong=", GameState.surgery_wrong)
	print("RESULT: ", "FAIL " + _fail if not _fail.is_empty() else "OK")
	get_tree().quit()
