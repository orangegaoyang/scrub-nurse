extends Node
## Headless check: surgery.tscn 全链路(真实场景节点)。
## 等医生第一次呼叫 -> SurgerySystem 拾取 -> 递送("啪"+记分) -> S1 归还
## -> 放回槽位 -> 下一件呼叫。跑完两件即算通过。
## Run: godot --headless res://tools/test_surgery_scene.tscn

var _scene: Node3D
var _sys: Node
var _surgeon: Node
var _fail := ""
var _delivered := 0


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/surgery.tscn")
	_scene = packed.instantiate()
	add_child(_scene)
	_sys = _scene.get_node("SurgerySystem")
	_surgeon = _scene.get_node("Surgeon")
	_drive()


func _drive() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	var target := 2
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		if GameState.current_phase != GameState.Phase.SURGERY:
			continue
		if _surgeon.is_returning():
			# 护士接回医生还的器械,放回 Mayo 原槽位
			var inst: Instrument = _surgeon.held_instrument
			_sys._take_back(inst)
			var slot := _find_slot(inst.def.slot_index)
			if slot == null:
				_fail = "找不到槽位 %d" % inst.def.slot_index
				break
			_sys._place_in_slot(slot)
			continue
		if _surgeon.is_demanding() and _sys.held_instrument == null:
			# 从 Mayo 槽位拿起医生要的器械
			var inst := _find_free_instrument(_surgeon.current_demand_id)
			if inst == null:
				_fail = "Mayo 上找不到 %s" % _surgeon.current_demand_id
				break
			_sys._pick_up(inst)
			if _sys.held_instrument != inst:
				_fail = "拾取失败: held=%s" % [_sys.held_instrument]
				break
			_sys._deliver(inst)
			if _surgeon.held_instrument != inst or GameState.surgery_correct != _delivered + 1:
				_fail = "递送失败"
				break
			_delivered += 1
		if _delivered >= target:
			break
	if _delivered < target and _fail.is_empty():
		_fail = "超时:只完成 %d/%d" % [_delivered, target]
	print("delivered=", _delivered, " correct=", GameState.surgery_correct,
			" wrong=", GameState.surgery_wrong,
			" demanding=", _surgeon.is_demanding(),
			" demand_id=", _surgeon.current_demand_id)
	print("RESULT: ", "FAIL " + _fail if not _fail.is_empty() else "OK")
	get_tree().quit()


func _find_free_instrument(id: String) -> Instrument:
	for c in _scene.get_node("MayoStand/SlotsParent").get_children():
		if c is TableSlot and c.current_instrument != null \
				and c.current_instrument.instrument_id == id:
			return c.current_instrument
	return null


func _find_slot(index: int) -> TableSlot:
	for c in _scene.get_node("MayoStand/SlotsParent").get_children():
		if c is TableSlot and c.slot_index == index:
			return c
	return null
