extends Node
## Surgery system v2.
##
## Doctor's line (player-independent): demand -> receive -> use -> deposit into
## the neutral-zone tray -> (gap) -> next demand. Discard items (gauze) never
## come back — the doctor keeps them, so those demands are pure deliver beats.
## The next demand fires on a timer after the deposit, WITHOUT waiting for the
## nurse to collect it. A full tray stalls the doctor (single back-pressure
## valve).
##
## Nurse's line: deliver from mayo/back table, collect from the neutral
## zone, then judge: still needed -> drop it back on the Mayo (free
## placement, no slots, overlapping allowed); finished -> back-table
## category zone. Misplacing a still-needed instrument is not rejected — the
## time cost of fetching it later IS the penalty (back-table zones still
## hard-reject a wrong category). After the last deposit the TIDY phase
## starts: everything must be cleared to the back table before the result
## screen.

const ACK_DEMAND_DELAY: float = 0.4  # surgeon reacts after the player acks the hint
# Gap between deposit and the next demand shrinks as the procedure goes on,
# so the surgeon's rhythm accelerates toward the end.
const GAP_START: float = 0.8
const GAP_END: float = 0.15
const USE_DURATION_MAX := 1.8
const USE_DURATION_MIN := 0.8
const DEPOSIT_SLIDE := 0.3  # hand travel to the tray before releasing
const TRAY_REST_Y := 0.92  # instruments lying on the mayo tray (local)

var player: CharacterBody3D
var held_parent: Node3D
var held_instrument: Instrument = null
var surgeon: Surgeon
var zone: NeutralZone = null
var mayo: Node3D
var back_zones_parent: Node3D

var _deliver_triggered: bool = false
var _from_zone: bool = false  # currently held instrument was collected from the neutral zone
var _first_deposit_hint: bool = false  # one-time "click the tray to collect"
var _full_zone_hint: bool = false  # one-time "tray is full, free a spot"
var _zones_lit: bool = false  # back-table zones light up at the first return
var _line_started: bool = false  # surgeon waits for the player's acknowledgment


func _ready() -> void:
	player = get_parent().get_node("Player")
	held_parent = get_parent().get_node("HeldParent")
	surgeon = get_parent().get_node_or_null("Surgeon")
	zone = get_parent().get_node_or_null("MayoStand/NeutralZone")
	mayo = get_parent().get_node("MayoStand")
	back_zones_parent = get_parent().get_node_or_null("BackTableZones")
	player.interact_pressed.connect(_on_interact)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.surgeon_line_start.connect(_on_surgeon_line_start)
	if surgeon != null:
		surgeon.zone = zone
		surgeon.instrument_deposited.connect(_on_deposited)
	if zone != null:
		zone.zone_freed.connect(_on_zone_freed)


func _process(_delta: float) -> void:
	if surgeon == null:
		return
	var phase: int = GameState.current_phase
	if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
		return
	if held_instrument != null:
		held_instrument.global_position = player.get_cursor_point() + Vector3(0, 0.05, 0)
		if phase == GameState.Phase.SURGERY:
			_check_delivery()
		_update_highlights()
	else:
		_hide_all_highlights()


# ---------------- Doctor's line ----------------

func _on_phase_changed(new_phase: int) -> void:
	if surgeon == null:
		return
	if new_phase == GameState.Phase.SURGERY:
		_first_deposit_hint = false
		_full_zone_hint = false
		_zones_lit = false
		_line_started = false
		# The surgeon holds until the player acknowledges the intro hint.
	elif new_phase == GameState.Phase.TIDY:
		if not ProcedureData.has_neutral_zone():
			# S1: the doctor's line ends with a hand-back or a gauze toss —
			# nothing to tidy, go straight to the result.
			GameState.finish_surgery(false)
			return
		GameState.set_back_table_count(_count_back_table())
		if ProcedureData.has_back_table():
			GameState.hint_changed.emit("收尾:把全部器械归位 back table", false)
		elif zone == null or zone.count() == 0:
			# S2 mini tidy over before it began (the last deposit was a toss).
			GameState.finish_surgery(false)
		else:
			GameState.hint_changed.emit("收尾:清空中立区,器械归位 Mayo", false)


func _on_surgeon_line_start() -> void:
	## The player clicked "知道了" on the intro hint — the surgeon may begin.
	if GameState.current_phase != GameState.Phase.SURGERY or _line_started:
		return
	_line_started = true
	_schedule_demand(ProcedureData.get_demand_at(0), ACK_DEMAND_DELAY, false)


func _schedule_demand(id: String, delay: float, keep_hand_out: bool) -> void:
	if surgeon == null:
		return
	_deliver_triggered = false
	await Util.wait(delay)
	if GameState.current_phase != GameState.Phase.SURGERY:
		return
	if not surgeon.is_demanding():
		surgeon.start_demand(id, keep_hand_out)


func _on_deposited(id: String) -> void:
	## The doctor just released the used instrument — into the tray, or (for
	## discard items like gauze) it's simply gone and never comes back.
	## Continue the line on his own clock — do NOT wait for the nurse.
	var def = ProcedureData.get_instrument(id)
	if def == null or not def.discard:
		if not _first_deposit_hint:
			_first_deposit_hint = true
			GameState.hint_changed.emit("用过的器械放中立区了——点击取回归位", false)
	if GameState.current_demand_index < ProcedureData.demand_count():
		var next_id: String = ProcedureData.get_demand_at(GameState.current_demand_index)
		_schedule_demand(next_id, _demand_gap(GameState.current_demand_index), true)
	else:
		surgeon.retract()
		# S3: tidy everything to the back table. S2: a mini tidy — clear the
		# neutral zone back onto the mayo.
		GameState.start_tidy()


func _on_zone_freed() -> void:
	## A waiting surgeon (tray was full) retries the deposit as soon as the
	## nurse collects something.
	if surgeon != null and surgeon.hand_waiting():
		_try_deposit()


func _use_sequence() -> void:
	## The doctor works with the delivered instrument. Discard items (gauze)
	## are kept by the doctor and never come back; everything else goes to the
	## neutral-zone tray (S2/S3) or back into the nurse's hand (S1).
	var duration: float = _use_duration(GameState.current_demand_index)
	await Util.wait(duration)
	if GameState.current_phase != GameState.Phase.SURGERY or surgeon == null:
		return
	if surgeon.held_instrument != null and surgeon.held_instrument.def != null \
			and surgeon.held_instrument.def.discard:
		surgeon.discard_held()  # gauze: the doctor keeps it, it never returns
		return
	if not ProcedureData.has_neutral_zone():
		surgeon.return_instrument()  # S1: direct hand-back, clickable
		return
	surgeon.finish_use()
	await Util.wait(DEPOSIT_SLIDE)
	if GameState.current_phase != GameState.Phase.SURGERY or surgeon == null:
		return
	_try_deposit()


func _try_deposit() -> void:
	if GameState.current_phase != GameState.Phase.SURGERY or surgeon == null:
		return
	if not surgeon.release_to_zone() and not _full_zone_hint:
		# Tray is full — the doctor waits; teach the capacity rule once.
		_full_zone_hint = true
		GameState.hint_changed.emit("中立区满了——取走一件医生才能继续", false)


func _use_duration(index: int) -> float:
	var total: int = ProcedureData.demand_count()
	if total <= 1:
		return USE_DURATION_MIN
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return lerpf(USE_DURATION_MAX, USE_DURATION_MIN, t)


func _demand_gap(index: int) -> float:
	var total: int = ProcedureData.demand_count()
	if total <= 1:
		return GAP_END
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return lerpf(GAP_START, GAP_END, t)


# ---------------- Delivery ----------------

func _check_delivery() -> void:
	if surgeon == null or held_instrument == null or not surgeon.is_demanding() or _deliver_triggered:
		return
	if player.get_cursor_hand() == surgeon.get_hand_area():
		_deliver_triggered = true
		_deliver(held_instrument)


func _deliver(inst: Instrument) -> void:
	var accepted: bool = surgeon.try_receive(inst)
	if accepted:
		held_instrument = null
		_from_zone = false
		inst.collision_layer = 0  # in the doctor's hand — no clicks
		GameState.set_held(null)
		GameState.record_correct()
		_use_sequence()
	else:
		inst.play_reject()


# ---------------- Nurse interaction ----------------

func _on_interact(_target: Node) -> void:
	var phase: int = GameState.current_phase
	if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
		return
	if held_instrument == null:
		var inst := player.get_cursor_instrument() as Instrument
		if inst != null:
			if inst.state == Instrument.State.IN_SURGEON and surgeon.is_returning() \
					and inst == surgeon.held_instrument:
				_take_back(inst)  # S1: the doctor hands it back directly
				return
			match inst.state:
				Instrument.State.IN_SLOT, Instrument.State.IN_ZONE, \
						Instrument.State.ON_MAYO:
					_pick_up(inst)
	else:
		var hit: Node = player.get_cursor_slot()
		if hit is BackZone:
			_place_in_zone(hit as BackZone)
			return
		if hit is TableSlot and not hit.occupied:
			_place_in_slot(hit as TableSlot)
			return
		if ProcedureData.surgery_free_mayo():
			var tray_point: Vector3 = player.get_cursor_tray_point()
			if tray_point != Vector3.INF:
				_place_on_mayo(tray_point)


func _take_back(inst: Instrument) -> void:
	## S1: collect the used instrument from the doctor's returning hand.
	held_instrument = inst
	surgeon.take_back()
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	_deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	GameState.hint_changed.emit("放回 Mayo 原槽位", false)


func _pick_up(inst: Instrument) -> void:
	held_instrument = inst
	_from_zone = inst.state == Instrument.State.IN_ZONE
	var parent: Node = inst.get_parent()
	var neutral: NeutralZone = null
	if parent is TableSlot:
		var slot := parent as TableSlot
		slot.occupied = false
		slot.current_instrument = null
		slot.clear_feedback()
		if slot.category != "":
			GameState.set_back_table_count(_count_back_table())
	elif _in_back_zone(inst):
		_get_back_zone(inst).remove_instrument(inst)
		GameState.set_back_table_count(_count_back_table())
	elif _in_neutral_zone(inst):
		neutral = _get_neutral_zone(inst)
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	_deliver_triggered = false
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	# Notify the tray only AFTER the anchor is actually free, so a waiting
	# surgeon retrying synchronously sees the free spot.
	if neutral != null:
		neutral.collected()
	_emit_return_hint()


func _emit_return_hint() -> void:
	## After collecting a used instrument, tell the player where it belongs.
	if not _from_zone or held_instrument == null:
		GameState.hint_changed.emit("", false)
		return
	var id: String = held_instrument.instrument_id
	var def = ProcedureData.get_instrument(id)
	if not ProcedureData.has_back_table():
		# S2: every instrument is reusable — back to the Mayo, always.
		GameState.hint_changed.emit("%s 放回 Mayo 台面" % def.name_cn, false)
		return
	var remaining: int = ProcedureData.remaining_uses(id, GameState.current_demand_index)
	if remaining > 0:
		GameState.hint_changed.emit("%s 还剩 %d 次 → 放回 Mayo 台面" % [def.name_cn, remaining], false)
	else:
		GameState.hint_changed.emit("%s 用完 → 放回 back table(按 Q)" % def.name_cn, false)


func _place_in_slot(slot: TableSlot) -> void:
	## S1 surgery: the returned instrument goes back to its own slot (hard).
	var inst: Instrument = held_instrument
	if slot.can_accept(inst):
		held_instrument = null
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
			# S1 coupled flow: the next demand waits for this return.
			if GameState.current_demand_index < ProcedureData.demand_count():
				_schedule_demand(ProcedureData.get_demand_at(GameState.current_demand_index),
					_demand_gap(GameState.current_demand_index), false)
			else:
				GameState.finish_surgery(false)
	else:
		slot.set_feedback(false)
		inst.play_reject()
		Sfx.play("slot_wrong")


func _place_on_mayo(point: Vector3) -> void:
	## Free placement during surgery: drop the instrument anywhere on the
	## Mayo tray, overlapping allowed. The player's own layout is the memory.
	var inst: Instrument = held_instrument
	held_instrument = null
	inst.set_state(Instrument.State.ON_MAYO)
	inst.reparent(mayo)
	var local := mayo.to_local(point)
	local.x = clampf(local.x, -0.42, 0.42)
	local.z = clampf(local.z, -0.28, 0.28)
	local.y = TRAY_REST_Y
	inst.position = local
	inst.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	inst.collision_layer = 1
	inst.freeze = true
	GameState.set_held(null)
	Sfx.play("slot_correct")
	GameState.hint_changed.emit("", false)
	_from_zone = false
	# S2 mini-tidy: once the neutral zone is cleared and the last instrument
	# is back on the mayo, the surgery is done.
	if GameState.current_phase == GameState.Phase.TIDY and (zone == null or zone.count() == 0):
		GameState.finish_surgery(false)


func _place_in_zone(bzone: BackZone) -> void:
	var inst: Instrument = held_instrument
	if bzone.can_accept(inst) and not bzone.is_full():
		held_instrument = null
		bzone.place_instrument(inst)
		inst.collision_layer = 1
		bzone.set_feedback(true)
		GameState.set_held(null)
		Sfx.play("slot_correct")
		GameState.hint_changed.emit("", false)
		_from_zone = false
		GameState.set_back_table_count(_count_back_table())
		if not _zones_lit:
			# First successful return: the back-table zones come alive.
			_zones_lit = true
			for c in back_zones_parent.get_children():
				if c is BackZone:
					(c as BackZone).set_dimmed(false)
	else:
		bzone.set_feedback(false)
		inst.play_reject()
		Sfx.play("slot_wrong")


func _count_back_table() -> int:
	## Everything already in its final place: back-table zone instruments
	## plus the gauze the doctor disposed of himself.
	var n: int = GameState.discarded_count
	if back_zones_parent == null:
		return n
	for c in back_zones_parent.get_children():
		if c is BackZone:
			n += (c as BackZone).current_instruments.size()
	return n


func _in_back_zone(inst: Instrument) -> bool:
	return Util.find_ancestor(inst.get_parent(), BackZone) != null


func _get_back_zone(inst: Instrument) -> BackZone:
	return Util.find_ancestor(inst.get_parent(), BackZone)


func _in_neutral_zone(inst: Instrument) -> bool:
	return Util.find_ancestor(inst.get_parent(), NeutralZone) != null


func _get_neutral_zone(inst: Instrument) -> NeutralZone:
	return Util.find_ancestor(inst.get_parent(), NeutralZone)


# ---------------- Placement highlights ----------------

func _update_highlights() -> void:
	## Only the back-table zones light up (when the held instrument belongs
	## there); the Mayo tray itself needs no guidance.
	if held_instrument == null or back_zones_parent == null:
		return
	for c in back_zones_parent.get_children():
		var bz := c as BackZone
		if bz == null:
			continue
		if not bz.is_full() and bz.can_accept(held_instrument):
			bz.show_place_highlight()
		else:
			bz.hide_highlight()


func _hide_all_highlights() -> void:
	if back_zones_parent == null:
		return
	for c in back_zones_parent.get_children():
		if c is BackZone:
			(c as BackZone).hide_highlight()
