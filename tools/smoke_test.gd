extends Node
## Headless end-to-end smoke test for the v2 loop. Run:
##   godot --headless --path . res://tools/smoke_test.tscn
## Drives the systems directly (no raycasts) through: prep segment 0
## (cart -> back-table zones) -> prep segment 1 (back table -> mayo slots) ->
## surgery (9-step reuse sequence with correct deliveries, neutral-zone
## deposits, reuse judgment, one wrong-category rejection) ->
## tidy-up -> result + star persistence.

const MAIN := preload("res://scenes/main.tscn")

var main: Node
var surgery
var pickup
var surgeon
var zone
var fails: Array[String] = []


func _ready() -> void:
	# Deterministic runs: wipe the persisted profile first.
	PlayerProfile._total_stars = 0
	PlayerProfile._proc_stars = {}
	PlayerProfile._save()
	# The main flow tests the full S3 procedure (neutral zone + back table).
	GameState.selected_surgery = {"procedure": "Craniotomy", "level": 3}
	main = MAIN.instantiate()
	add_child(main)
	_run()


func _run() -> void:
	await Util.wait(0.8)  # cart pile settle (main._spawn_instruments waits 0.5s)
	surgery = main.get_node("SurgerySystem")
	pickup = main.get_node("PickupSystem")
	surgeon = main.get_node("Surgeon")
	zone = main.get_node("MayoStand/NeutralZone")
	print("== smoke test start ==")

	await _test_prep()
	await _test_surgery()
	_test_levels()
	_test_ghost_tier_math()
	await _test_free_mayo()
	await _test_backpressure()
	await _test_s1()
	await _test_s2()

	print("== smoke test done: %d fails ==" % fails.size())
	for f in fails:
		print("FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() else 1)


# ---------------- Prep ----------------

func _test_prep() -> void:
	_check(GameState.current_phase == GameState.Phase.PREP, "phase starts PREP")
	var scattered: Array = _instruments_with_state(Instrument.State.IN_TRAY)
	_check(scattered.size() == ProcedureData.instrument_order.size(),
		"all %d instruments scattered on the back table, got %d" % [ProcedureData.instrument_order.size(), scattered.size()])
	for inst in scattered:
		pickup._pick_up(inst)
		_check(main.get_node("UI/HeldInfo").visible, "held-info text visible while holding")
		if inst.def.slot_index < 6:
			pickup._place_in_slot(_slot_for(inst.def.slot_index))
		else:
			pickup._place_in_zone(_zone_for_category(inst.def.category))
	_check(GameState.prep_correct + GameState.prep_back_correct == ProcedureData.instrument_order.size(),
		"all %d instruments placed (mayo + back zones)" % ProcedureData.instrument_order.size())
	_check(GameState.current_phase == GameState.Phase.COUNTDOWN, "phase COUNTDOWN after prep")
	GameState.start_surgery()
	GameState.surgeon_line_start.emit()  # acknowledge the intro hint
	_check(GameState.current_phase == GameState.Phase.SURGERY, "phase SURGERY")


# ---------------- Surgery ----------------

func _test_surgery() -> void:
	_check(GameState.guidance_tier() == 1, "fresh profile starts at guidance tier 1")
	# Surgery: the mayo slots are hidden — the tray is free placement.
	var hidden: bool = true
	for c in main.get_node("MayoStand/SlotsParent").get_children():
		if (c as TableSlot).collision_layer != 0:
			hidden = false
	_check(hidden, "mayo slots hidden during surgery")
	var expected: Array = ProcedureData.demand_sequence.duplicate()
	var delivered: int = 0
	while delivered < expected.size():
		if not await _wait_until(func(): return surgeon.is_demanding(), 5.0):
			print("DEBUG demand %d missing: surgeon.state=%d demand=%s index=%d phase=%d" % [
				delivered + 1, surgeon.state, surgeon.current_demand_id,
				GameState.current_demand_index, GameState.current_phase])
		_check(surgeon.is_demanding(), "surgeon demanded step %d" % (delivered + 1))
		var demanded_id: String = expected[delivered]
		var inst := _find_instrument(demanded_id)
		_check(inst != null, "instrument %s found for delivery" % demanded_id)
		surgery._pick_up(inst)
		surgery._deliver(inst)
		var accepted: bool = inst.state == Instrument.State.IN_SURGEON or surgeon.held_instrument == inst
		_check(accepted, "delivery of %s accepted" % demanded_id)
		if not accepted:
			print("DEBUG state=", surgeon.state, " demand=", surgeon.current_demand_id,
				" surgeon_held=", surgeon.held_instrument, " inst=", inst.instrument_id,
				" inst_state=", inst.state, " cooldown=", surgeon._reject_cooldown)
			break
		delivered += 1
		# Discard items (gauze): the doctor keeps them off-frame — no
		# neutral-zone deposit, no return judgment, just a disposal count.
		if inst.def.discard:
			var before: int = GameState.discarded_count
			_check(await _wait_until(func(): return GameState.discarded_count > before, 8.0),
				"discard item %s disposed of by the doctor" % demanded_id)
			continue
		# Wait for the deposit into the neutral zone.
		_check(await _wait_until(func(): return _find_in_zone(demanded_id) != null, 8.0),
			"instrument %s deposited into neutral zone" % demanded_id)
		var zinst := _find_in_zone(demanded_id)
		# Reuse judgment: still needed -> free drop on Mayo; finished -> back table.
		var remaining: int = ProcedureData.remaining_uses(demanded_id, GameState.current_demand_index)
		surgery._pick_up(zinst)
		if remaining > 0:
			surgery._place_on_mayo(mayo_center_point())
			_check(_find_in_mayo(demanded_id) != null, "reusable %s back on mayo (free drop)" % demanded_id)
		else:
			var wrong_zone := _zone_for_other_category(inst.def.category)
			if wrong_zone != null:
				surgery._place_in_zone(wrong_zone)
				_check(surgery.held_instrument == inst, "wrong category rejected (still held)")
			var bz := _zone_for_category(inst.def.category)
			surgery._place_in_zone(bz)
			if _find_in_back(demanded_id) == null:
				print("DEBUG %s: state=%d parent=%s grandparent=%s held=%s bz_full=%s cap=%d" % [
					demanded_id, inst.state, inst.get_parent(), inst.get_parent().get_parent(),
					surgery.held_instrument, bz.is_full(), bz.get_capacity()
				])
			_check(_find_in_back(demanded_id) != null, "finished %s placed on back table" % demanded_id)
	_check(delivered == expected.size(), "all %d demands delivered" % expected.size())
	_check(await _wait_until(func():
			return GameState.current_phase == GameState.Phase.TIDY \
				or GameState.current_phase == GameState.Phase.RESULT, 10.0),
		"phase TIDY after last deposit (may jump straight to RESULT when already tidy)")
	# Tidy: everything left over (mayo / zone) goes to the back table.
	for inst in _instruments_not_on_back():
		surgery._pick_up(inst)
		surgery._place_in_zone(_zone_for_category(inst.def.category))
	_check(await _wait_until(func(): return GameState.current_phase == GameState.Phase.RESULT, 5.0),
		"phase RESULT after tidy")
	_check(main.get_node("UI").visible, "UI layer visible at RESULT")
	_check(main.get_node("UI/Result").visible, "result card visible at RESULT")
	_check(GameState.last_stars == 3, "3 stars for a perfect run, got %d" % GameState.last_stars)


# ---------------- Levels / guidance ----------------

func _test_levels() -> void:
	var proc_id: String = GameState.current_procedure_id()
	var before: int = PlayerProfile.procedure_stars(proc_id)
	_check(before == GameState.last_stars, "procedure star pool fed by the run")
	_check(PlayerProfile.total_stars >= GameState.last_stars, "global pool fed by the run")
	var lvl: int = PlayerProfile.procedure_level(proc_id)
	_check(lvl >= 1 and lvl <= 3, "procedure level valid")
	PlayerProfile.add_surgery_result("FakeProcedure", 5)
	_check(PlayerProfile.procedure_level("FakeProcedure") == 2, "5 stars -> Level II")
	PlayerProfile.add_surgery_result("FakeProcedure", 7)
	_check(PlayerProfile.procedure_level("FakeProcedure") == 3, "12 stars -> Level III")


func _test_ghost_tier_math() -> void:
	_check(PlayerProfile.global_level() >= 1, "global level valid")


func _test_free_mayo() -> void:
	## Surgery has no mayo slots at all: free placement, overlap allowed.
	var proc_id: String = GameState.current_procedure_id()
	PlayerProfile.add_surgery_result(proc_id, 5)  # levels no longer touch the mayo
	GameState.current_phase = GameState.Phase.SURGERY
	GameState.surgeon_line_start.emit()
	await _frames(1)
	var hidden: bool = true
	for c in main.get_node("MayoStand/SlotsParent").get_children():
		if (c as TableSlot).collision_layer != 0:
			hidden = false
	_check(hidden, "mayo slots hidden during surgery (free tray)")
	# Free drop accepts any instrument anywhere on the tray.
	var inst := _find_in_back("hemostat")
	surgery._pick_up(inst)
	surgery._place_on_mayo(mayo_center_point() + Vector3(0.2, 0, 0))
	_check(_find_in_mayo("hemostat") != null, "free drop on mayo accepted")
	# Overlap allowed: drop another instrument on the SAME spot.
	var inst2 := _find_in_back("scissors")
	surgery._pick_up(inst2)
	surgery._place_on_mayo(mayo_center_point() + Vector3(0.2, 0, 0))
	_check(_find_in_mayo("scissors") != null, "overlapping drop on mayo accepted")
	GameState.current_phase = GameState.Phase.RESULT


# ---------------- Helpers ----------------

func _test_backpressure() -> void:
	## Tray-full back-pressure: deliver 3 instruments without collecting —
	## the surgeon must WAIT holding the 4th until the nurse frees a spot.
	GameState.reset()
	GameState.current_phase = GameState.Phase.SURGERY
	GameState.surgeon_line_start.emit()
	# Stage all instruments onto the mayo tray for this scenario.
	for inst in _instruments_not_on_back():
		surgery._pick_up(inst)
		surgery._place_on_mayo(mayo_center_point())
	for i in 3:
		_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0),
			"backpressure: demand %d fired" % (i + 1))
		var id: String = ProcedureData.get_demand_at(GameState.current_demand_index)
		var inst := _find_instrument(id)
		surgery._pick_up(inst)
		surgery._deliver(inst)
		_check(await _wait_until(func(): return _find_in_zone(id) != null, 8.0),
			"backpressure: %s deposited" % id)
	_check(zone.is_full(), "neutral zone full after 3 deposits")
	# 4th demand: deliver it, then the surgeon waits (zone full).
	_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0),
		"backpressure: demand 4 fired")
	var fourth_id: String = ProcedureData.get_demand_at(GameState.current_demand_index)
	var fourth := _find_instrument(fourth_id)
	surgery._pick_up(fourth)
	surgery._deliver(fourth)
	_check(await _wait_until(func(): return surgeon.hand_waiting(), 15.0),
		"surgeon WAITS holding the used instrument when the tray is full")
	_check(GameState.current_demand_index == 4, "demand sequence stalled at step 4")
	_check(_find_in_zone(fourth_id) == null, "%s NOT deposited while tray full" % fourth_id)
	# Free a spot: collect scalpel -> zone_freed -> the surgeon deposits.
	var zinst := _find_in_zone("scalpel")
	surgery._pick_up(zinst)
	surgery._place_in_zone(_zone_for_category("cutting"))
	_check(await _wait_until(func(): return not surgeon.hand_waiting(), 8.0),
		"surgeon deposits as soon as the nurse frees a spot")
	_check(await _wait_until(func(): return _find_in_zone(fourth_id) != null, 8.0),
		"%s deposited after the spot freed" % fourth_id)
	GameState.current_phase = GameState.Phase.RESULT


# ---------------- S1 / S2 procedure flows ----------------

func _test_s1() -> void:
	## S1 (Appendectomy): Mayo only — direct hand-back + slot returns.
	main.queue_free()
	GameState.selected_surgery = {"procedure": "Appendectomy", "level": 1}
	var s1main: Node = MAIN.instantiate()
	add_child(s1main)
	await Util.wait(3.0)
	var pickup: Node = s1main.get_node("PickupSystem")
	var surgery: Node = s1main.get_node("SurgerySystem")
	var surgeon: Node = s1main.get_node("Surgeon")
	_check(s1main.get_node("small_backtable").visible, "S1: back table visible as the prep staging surface")
	_check(not s1main.get_node("MayoStand/NeutralZone").visible, "S1: neutral zone hidden")
	var tray := _instruments_of(s1main, Instrument.State.IN_TRAY)
	_check(tray.size() == 4, "S1: 4 instruments scattered on the back table, got %d" % tray.size())
	for inst in tray:
		pickup._pick_up(inst)
		pickup._place_in_slot(_slot_for_in(s1main, inst.def.slot_index))
	GameState.start_surgery()
	_check(not s1main.get_node("small_backtable").visible, "S1: back table hidden once surgery starts")
	# S1 has no intro hint: the surgeon begins on his own clock.
	_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0), "S1: first demand fired")
	var expected: Array = ProcedureData.demand_sequence.duplicate()
	var delivered: int = 0
	while delivered < expected.size():
		var id: String = expected[delivered]
		var inst := _find_in_main(s1main, id, -1)
		surgery._pick_up(inst)
		surgery._deliver(inst)
		delivered += 1
		var def = ProcedureData.get_instrument(id)
		if def != null and def.discard:
			var before: int = GameState.discarded_count
			_check(await _wait_until(func(): return GameState.discarded_count > before, 8.0),
				"S1: %s disposed of by the doctor" % id)
			if delivered == expected.size():
				_check(await _wait_until(func(): return GameState.current_phase == GameState.Phase.RESULT, 5.0),
					"S1: RESULT after the final disposal")
			else:
				_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0),
					"S1: next demand after the disposal")
			continue
		_check(await _wait_until(func(): return surgeon.is_returning(), 8.0),
			"S1: doctor hands back step %d" % delivered)
		var used := _find_in_main(s1main, id, Instrument.State.IN_SURGEON)
		surgery._take_back(used)
		surgery._place_in_slot(_slot_for_in(s1main, used.def.slot_index))
		if delivered < expected.size():
			_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0),
				"S1: next demand after slot return")
		else:
			_check(await _wait_until(func(): return GameState.current_phase == GameState.Phase.RESULT, 5.0),
				"S1: RESULT after final slot return")
	s1main.queue_free()


func _test_s2() -> void:
	## S2 (Knee): neutral zone + all-reusable + free mayo; back table is a
	## prep staging surface only.
	GameState.selected_surgery = {"procedure": "Total Knee Replacement", "level": 2}
	var s2main: Node = MAIN.instantiate()
	add_child(s2main)
	await Util.wait(3.0)
	var pickup: Node = s2main.get_node("PickupSystem")
	var surgery: Node = s2main.get_node("SurgerySystem")
	var surgeon: Node = s2main.get_node("Surgeon")
	var zone: Node = s2main.get_node("MayoStand/NeutralZone")
	_check(s2main.get_node("small_backtable").visible, "S2: back table visible during prep")
	var tray := _instruments_of(s2main, Instrument.State.IN_TRAY)
	_check(tray.size() == 6, "S2: 6 instruments scattered, got %d" % tray.size())
	for inst in tray:
		pickup._pick_up(inst)
		pickup._place_in_slot(_slot_for_in(s2main, inst.def.slot_index))
	GameState.start_surgery()
	GameState.surgeon_line_start.emit()  # ack the intro hint
	await _frames(1)
	_check(not s2main.get_node("small_backtable").visible, "S2: back table hidden during surgery")
	_check(zone.visible, "S2: neutral zone visible during surgery")
	var on_mayo := _instruments_of(s2main, Instrument.State.ON_MAYO)
	_check(on_mayo.size() == 8, "S2: prep layout + 2 gauze spares released onto the free tray")
	var expected: Array = ProcedureData.demand_sequence.duplicate()
	var delivered: int = 0
	while delivered < expected.size():
		_check(await _wait_until(func(): return surgeon.is_demanding(), 6.0),
			"S2: demand %d" % (delivered + 1))
		var id: String = expected[delivered]
		var inst := _find_in_main(s2main, id, -1)
		surgery._pick_up(inst)
		surgery._deliver(inst)
		delivered += 1
		if inst.def.discard:
			var before: int = GameState.discarded_count
			_check(await _wait_until(func(): return GameState.discarded_count > before, 8.0),
				"S2: %s disposed of by the doctor" % id)
			continue
		_check(await _wait_until(func(): return _find_in_main(s2main, id, Instrument.State.IN_ZONE) != null, 8.0),
			"S2: %s deposited" % id)
		var zinst := _find_in_main(s2main, id, Instrument.State.IN_ZONE)
		surgery._pick_up(zinst)
		surgery._place_on_mayo(s2main.get_node("MayoStand").global_position + Vector3(0, 0.93, 0))
	# The last deposit starts the mini tidy; with everything already cleared
	# (the last deposit was a toss) it finishes immediately.
	_check(await _wait_until(func(): return GameState.current_phase == GameState.Phase.RESULT, 8.0),
		"S2: RESULT after mini tidy")
	s2main.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _instruments_of(m: Node, state: int) -> Array:
	var out: Array = []
	_collect_in(m, out)
	if state < 0:
		return out
	var filtered: Array = []
	for inst in out:
		if inst.state == state:
			filtered.append(inst)
	return filtered


func _collect_in(n: Node, out: Array) -> void:
	if n is Instrument:
		out.append(n)
	for c in n.get_children():
		_collect_in(c, out)


func _find_in_main(m: Node, id: String, state: int) -> Instrument:
	for inst in _instruments_of(m, -1):
		if inst.instrument_id != id:
			continue
		if state >= 0:
			if inst.state == state:
				return inst
		elif inst.state != Instrument.State.IN_SURGEON:
			return inst
	return null


func _slot_for_in(m: Node, index: int) -> TableSlot:
	for c in m.get_node("MayoStand/SlotsParent").get_children():
		var slot := c as TableSlot
		if slot != null and slot.slot_index == index:
			return slot
	return null


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t: float = 0.0
	while t < timeout:
		if cond.call():
			return true
		await Util.wait(0.1)
		t += 0.1
	return false


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: ", what)
	else:
		fails.append(what)
		print("  FAIL: ", what)


func _all_instruments() -> Array[Instrument]:
	var out: Array[Instrument] = []
	_collect_instruments(main, out)
	return out


func _collect_instruments(n: Node, out: Array) -> void:
	if n is Instrument:
		out.append(n)
	for c in n.get_children():
		_collect_instruments(c, out)


func _instruments_with_state(state: int) -> Array:
	var out: Array = []
	for inst in _all_instruments():
		if inst.state == state:
			out.append(inst)
	return out


func _find_instrument(id: String) -> Instrument:
	for inst in _all_instruments():
		if inst.instrument_id == id and inst.state != Instrument.State.IN_SURGEON:
			return inst
	return null


func _find_in_zone(id: String) -> Instrument:
	for inst in _all_instruments():
		if inst.instrument_id == id and inst.state == Instrument.State.IN_ZONE:
			return inst
	return null


func _find_in_mayo(id: String) -> Instrument:
	for inst in _all_instruments():
		if inst.instrument_id == id and inst.state == Instrument.State.ON_MAYO:
			return inst
	return null


func mayo_center_point() -> Vector3:
	return main.get_node("MayoStand").global_position + Vector3(0, 0.93, 0)


func _find_in_back(id: String) -> Instrument:
	for inst in _all_instruments():
		if inst.instrument_id == id and _in_back_zone(inst):
			return inst
	return null


func _in_back_zone(inst: Instrument) -> bool:
	var p: Node = inst.get_parent()
	return p is BackZone or (p != null and p.get_parent() is BackZone)


func _instruments_not_on_back() -> Array:
	var out: Array = []
	for inst in _all_instruments():
		if not _in_back_zone(inst):
			out.append(inst)
	return out


func _back_zones() -> Array:
	var out: Array = []
	for c in main.get_node("BackTableZones").get_children():
		if c is BackZone:
			out.append(c)
	return out


func _zone_for_category(cat: String) -> BackZone:
	for bz in _back_zones():
		if bz.category == cat:
			return bz
	return null


func _zone_for_other_category(cat: String) -> BackZone:
	for bz in _back_zones():
		if bz.category != cat:
			return bz
	return null


func _slot_for(index: int) -> TableSlot:
	for c in main.get_node("MayoStand/SlotsParent").get_children():
		var slot := c as TableSlot
		if slot != null and slot.slot_index == index:
			return slot
	return null
