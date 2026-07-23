extends Node
## Surgery system: pickup from slot, follow cursor, deliver by touching hand,
## take back, replace in original slot.

var player: CharacterBody3D
var held_parent: Node3D
var held_instrument: Instrument = null
var surgeon: Surgeon
var _deliver_triggered: bool = false


func _ready() -> void:
	player = get_parent().get_node("Player")
	held_parent = get_parent().get_node("HeldParent")
	surgeon = get_parent().get_node("Surgeon")
	player.interact_pressed.connect(_on_interact)
	GameState.phase_changed.connect(_on_phase_changed)


func _process(_delta: float) -> void:
	if GameState.current_phase != GameState.Phase.SURGERY:
		return
	if held_instrument != null:
		held_instrument.global_position = player.get_cursor_point() + Vector3(0, 0.05, 0)
		_check_delivery()


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.SURGERY:
		_start_demand(ProcedureData.get_demand_at(GameState.current_demand_index))


func _start_demand(id: String) -> void:
	_deliver_triggered = false
	surgeon.start_demand(id)


func _check_delivery() -> void:
	if held_instrument == null or not surgeon.is_demanding() or _deliver_triggered:
		return
	if player.get_cursor_collider() == surgeon.get_hand_area():
		_deliver_triggered = true
		_deliver(held_instrument)


func _deliver(inst: Instrument) -> void:
	var accepted: bool = surgeon.try_receive(inst)
	if accepted:
		held_instrument = null
		inst.collision_layer = 1  # surgeon holds it; allow cursor to hit for take-back
		GameState.surgery_correct += 1
		GameState.current_demand_index += 1
		GameState.score_updated.emit()


func _on_interact(target: Node) -> void:
	if GameState.current_phase != GameState.Phase.SURGERY:
		return
	if held_instrument == null:
		if target is Instrument:
			var inst := target as Instrument
			if inst.state == Instrument.State.IN_SLOT:
				_pick_up_from_slot(inst)
			elif surgeon.is_returning() and inst == surgeon.held_instrument:
				_take_back(inst)
	else:
		if target is TableSlot and not (target as TableSlot).occupied:
			_place_in_slot(target as TableSlot)


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


func _take_back(inst: Instrument) -> void:
	held_instrument = inst
	surgeon.take_back()
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	_deliver_triggered = false
	if GameState.current_demand_index < ProcedureData.demand_sequence.size():
		_start_demand(ProcedureData.get_demand_at(GameState.current_demand_index))


func _place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = held_instrument
	if slot.can_accept(inst):
		held_instrument = null
		inst.set_state(Instrument.State.IN_SLOT)
		inst.reparent(slot)
		inst.transform = Transform3D.IDENTITY
		inst.position = Vector3(0, 0.04, 0)
		inst.collision_layer = 1
		slot.occupied = true
		slot.current_instrument = inst
		slot.set_feedback(true)
		if GameState.current_demand_index >= ProcedureData.demand_sequence.size():
			GameState.finish_surgery()
	else:
		slot.set_feedback(false)
