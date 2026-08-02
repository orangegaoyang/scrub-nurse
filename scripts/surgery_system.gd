extends Node
## Surgery system: pickup from slot, follow cursor, deliver by touching hand,
## take back, replace in original slot.

const FIRST_DEMAND_DELAY: float = 1.0
# Cadence between take-back and the next demand shrinks as the procedure goes
# on, so the surgeon's hand-extension rhythm accelerates toward the end.
const GAP_START: float = 0.8
const GAP_END: float = 0.15

var player: CharacterBody3D
var held_parent: Node3D
var held_instrument: Instrument = null
var surgeon: Surgeon
var _deliver_triggered: bool = false
var _awaiting_demand: bool = false


func _ready() -> void:
	player = get_parent().get_node("Player")
	held_parent = get_parent().get_node("HeldParent")
	surgeon = get_parent().get_node_or_null("Surgeon")
	player.interact_pressed.connect(_on_interact)
	GameState.phase_changed.connect(_on_phase_changed)


func _process(_delta: float) -> void:
	if surgeon == null or GameState.current_phase != GameState.Phase.SURGERY:
		return
	if held_instrument != null:
		held_instrument.global_position = player.get_cursor_point() + Vector3(0, 0.05, 0)
		_check_delivery()


func _on_phase_changed(new_phase: int) -> void:
	if surgeon == null:
		return
	if new_phase == GameState.Phase.SURGERY:
		_schedule_demand(ProcedureData.get_demand_at(GameState.current_demand_index), FIRST_DEMAND_DELAY, false)


func _schedule_demand(id: String, delay: float, keep_hand_out: bool) -> void:
	if surgeon == null:
		return
	_deliver_triggered = false
	_awaiting_demand = true
	await get_tree().create_timer(delay).timeout
	_awaiting_demand = false
	if GameState.current_phase == GameState.Phase.SURGERY and not surgeon.is_demanding():
		surgeon.start_demand(id, keep_hand_out)


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
		inst.collision_layer = 1  # surgeon holds it; allow cursor to hit for take-back
		GameState.set_held(null)
		GameState.surgery_correct += 1
		GameState.current_demand_index += 1
		GameState.score_updated.emit()
	else:
		inst.play_reject()


func _on_interact(_target: Node) -> void:
	if GameState.current_phase != GameState.Phase.SURGERY:
		return
	if held_instrument == null:
		var inst := player.get_cursor_instrument() as Instrument
		if inst != null:
			if inst.state == Instrument.State.IN_SLOT:
				_pick_up_from_slot(inst)
			elif surgeon.is_returning() and inst == surgeon.held_instrument:
				_take_back(inst)
	else:
		var slot := player.get_cursor_slot() as TableSlot
		if slot != null and not slot.occupied:
			_place_in_slot(slot)


func _pick_up_from_slot(inst: Instrument) -> void:
	held_instrument = inst
	var slot = inst.get_parent()
	if slot is TableSlot:
		slot.occupied = false
		slot.current_instrument = null
		slot.clear_feedback()
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	_deliver_triggered = false
	GameState.set_held(inst)


func _take_back(inst: Instrument) -> void:
	held_instrument = inst
	var has_next: bool = GameState.current_demand_index < ProcedureData.demand_sequence.size()
	# Keep the hand out for a continuous rhythm; only the gap before the next
	# demand shrinks (accelerating) as progress grows.
	var keep_hand_out: bool = has_next
	var delay: float = 0.0
	if has_next:
		delay = _demand_gap(GameState.current_demand_index)
	surgeon.take_back(keep_hand_out)
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	_deliver_triggered = false
	GameState.set_held(inst)
	if has_next:
		_schedule_demand(ProcedureData.get_demand_at(GameState.current_demand_index), delay, keep_hand_out)


func _demand_gap(index: int) -> float:
	var total: int = ProcedureData.demand_sequence.size()
	if total <= 1:
		return GAP_END
	var t: float = clampf(float(index) / float(total - 1), 0.0, 1.0)
	return lerpf(GAP_START, GAP_END, t)


func _place_in_slot(slot: TableSlot) -> void:
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
		if GameState.current_demand_index >= ProcedureData.demand_sequence.size():
			GameState.finish_surgery()
	else:
		slot.set_feedback(false)
		inst.play_reject()
