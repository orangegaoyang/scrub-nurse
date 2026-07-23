extends Node
## Surgery system: pickup from slot, deliver by touch, take back, replace.

var player: CharacterBody3D
var hold_point: Node3D
var held_instrument: Instrument = null
var surgeon: Surgeon
var hud: Control


func _ready() -> void:
	player = get_parent().get_node("Player")
	hold_point = player.get_node("Camera3D/HoldPoint")
	surgeon = get_parent().get_node("Surgeon")
	hud = get_parent().get_node("UI/HUD")
	player.interact_pressed.connect(_on_interact)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.SURGERY:
		_start_demand(ProcedureData.get_demand_at(GameState.current_demand_index))


func _start_demand(id: String) -> void:
	surgeon.start_demand(id)


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
	inst.reparent(hold_point)
	inst.transform = Transform3D.IDENTITY
	inst.rotation_degrees.x = 15.0
	_connect_delivery(inst)


func _take_back(inst: Instrument) -> void:
	held_instrument = inst
	surgeon.take_back()
	inst.set_state(Instrument.State.HELD)
	inst.reparent(hold_point)
	inst.transform = Transform3D.IDENTITY
	inst.rotation_degrees.x = 15.0
	_connect_delivery(inst)
	# Demand index was already advanced on delivery; start next if any remain.
	if GameState.current_demand_index < ProcedureData.demand_sequence.size():
		_start_demand(ProcedureData.get_demand_at(GameState.current_demand_index))


func _place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = held_instrument
	if slot.can_accept(inst):
		_disconnect_delivery(inst)
		held_instrument = null
		inst.set_state(Instrument.State.IN_SLOT)
		inst.reparent(slot)
		inst.transform = Transform3D.IDENTITY
		inst.position = Vector3(0, 0.04, 0)
		slot.occupied = true
		slot.current_instrument = inst
		slot.set_feedback(true)
		# If all demands fulfilled, surgery is complete after final replace.
		if GameState.current_demand_index >= ProcedureData.demand_sequence.size():
			GameState.finish_surgery()
	else:
		slot.set_feedback(false)


# ---- Delivery by touch ----

func _connect_delivery(inst: Instrument) -> void:
	var da: Area3D = inst.get_node("DeliveryArea")
	if not da.area_entered.is_connected(_on_held_delivery_entered):
		da.area_entered.connect(_on_held_delivery_entered)


func _disconnect_delivery(inst: Instrument) -> void:
	if inst == null or not inst.has_node("DeliveryArea"):
		return
	var da: Area3D = inst.get_node("DeliveryArea")
	if da.area_entered.is_connected(_on_held_delivery_entered):
		da.area_entered.disconnect(_on_held_delivery_entered)


func _on_held_delivery_entered(area: Area3D) -> void:
	if held_instrument == null:
		return
	if not surgeon.is_demanding():
		return
	if area == surgeon.get_hand_area():
		var inst: Instrument = held_instrument
		var accepted: bool = surgeon.try_receive(inst)
		if accepted:
			_disconnect_delivery(inst)
			held_instrument = null
			GameState.surgery_correct += 1
			GameState.current_demand_index += 1
			GameState.score_updated.emit()
