extends Node
## Pickup system (prep phase): grab from tray, follow cursor, place in correct slot.

const SNAP_DIST := 0.08

var player: CharacterBody3D
var held_parent: Node3D
var held_instrument: Instrument = null
var voice: AudioStreamPlayer
var slots_parent: Node3D
var inspect: InspectSystem


func _ready() -> void:
	player = get_parent().get_node("Player")
	held_parent = get_parent().get_node("HeldParent")
	slots_parent = get_parent().get_node("MayoStand/SlotsParent")
	inspect = get_parent().get_node_or_null("InspectSystem")
	voice = AudioStreamPlayer.new()
	add_child(voice)
	player.interact_pressed.connect(_on_interact)
	player.inspect_pressed.connect(_on_inspect)


func _process(_delta: float) -> void:
	if held_instrument != null:
		var target: Vector3 = player.get_cursor_point() + Vector3(0, 0.05, 0)
		var slot := _highlighted_slot()
		if slot != null:
			var d := Vector2(target.x - slot.global_position.x, target.z - slot.global_position.z).length()
			if d <= SNAP_DIST:
				# Snap onto the highlighted (correct) slot, keeping held height.
				target.x = slot.global_position.x
				target.z = slot.global_position.z
		held_instrument.global_position = target


func _highlighted_slot() -> TableSlot:
	# The matching, empty slot — the one showing the white frame.
	for s in slots_parent.get_children():
		var slot := s as TableSlot
		if slot != null and not slot.occupied and slot.can_accept(held_instrument):
			return slot
	return null


func _on_interact(_target: Node) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		return
	if inspect != null and inspect.is_inspecting():
		return
	if held_instrument == null:
		var inst := player.get_cursor_instrument() as Instrument
		if inst != null and inst.state == Instrument.State.IN_TRAY:
			_pick_up(inst)
	else:
		var slot := player.get_cursor_slot() as TableSlot
		if slot != null and not slot.occupied:
			_place_in_slot(slot)


func _on_inspect() -> void:
	# Right-click during prep: bring the instrument under the cursor up for a
	# close look. Disabled while holding (placing takes priority) or already
	# inspecting.
	if GameState.current_phase != GameState.Phase.PREP:
		return
	if inspect == null or inspect.is_inspecting() or held_instrument != null:
		return
	var inst := player.get_cursor_instrument() as Instrument
	if inst != null:
		inspect.inspect(inst)


func _pick_up(inst: Instrument) -> void:
	held_instrument = inst
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	GameState.set_held(inst)
	Util.play_voice(voice, inst.instrument_id)


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
		GameState.prep_correct += 1
		GameState.prep_item_secured.emit(inst.instrument_id)
		GameState.score_updated.emit()
		if GameState.prep_correct >= ProcedureData.demand_sequence.size():
			GameState.start_countdown()
	else:
		slot.set_feedback(false)
		inst.play_reject()
