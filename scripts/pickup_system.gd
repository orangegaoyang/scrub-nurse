extends Node
## Pickup system (prep phase): grab instruments from tray, place into correct slots.

var player: CharacterBody3D
var hold_point: Node3D
var held_instrument: Instrument = null


func _ready() -> void:
	player = get_parent().get_node("Player")
	hold_point = player.get_node("Camera3D/HoldPoint")
	player.interact_pressed.connect(_on_interact)


func _on_interact(target: Node) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		return
	if held_instrument == null:
		if target is Instrument and (target as Instrument).state == Instrument.State.IN_TRAY:
			_pick_up(target as Instrument)
	else:
		if target is TableSlot and not (target as TableSlot).occupied:
			_place_in_slot(target as TableSlot)


func _pick_up(inst: Instrument) -> void:
	held_instrument = inst
	inst.set_state(Instrument.State.HELD)
	inst.reparent(hold_point)
	inst.transform = Transform3D.IDENTITY
	inst.rotation_degrees.x = 15.0


func _place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = held_instrument
	if slot.can_accept(inst):
		held_instrument = null
		inst.set_state(Instrument.State.IN_SLOT)
		inst.reparent(slot)
		inst.transform = Transform3D.IDENTITY
		inst.position = Vector3(0, 0.04, 0)
		slot.occupied = true
		slot.current_instrument = inst
		slot.set_feedback(true)
		GameState.prep_correct += 1
		GameState.score_updated.emit()
		if GameState.prep_correct >= ProcedureData.demand_sequence.size():
			GameState.start_countdown()
	else:
		slot.set_feedback(false)
