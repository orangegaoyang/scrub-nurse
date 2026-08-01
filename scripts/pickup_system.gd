extends Node
## Pickup system (prep phase): grab from tray, follow cursor, place in correct slot.

var player: CharacterBody3D
var held_parent: Node3D
var held_instrument: Instrument = null
var voice: AudioStreamPlayer


func _ready() -> void:
	player = get_parent().get_node("Player")
	held_parent = get_parent().get_node("HeldParent")
	voice = AudioStreamPlayer.new()
	add_child(voice)
	player.interact_pressed.connect(_on_interact)


func _process(_delta: float) -> void:
	if held_instrument != null:
		held_instrument.global_position = player.get_cursor_point() + Vector3(0, 0.05, 0)


func _on_interact(_target: Node) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		return
	if held_instrument == null:
		var inst := player.get_cursor_instrument() as Instrument
		if inst != null and inst.state == Instrument.State.IN_TRAY:
			_pick_up(inst)
	else:
		var slot := player.get_cursor_slot() as TableSlot
		if slot != null and not slot.occupied:
			_place_in_slot(slot)


func _pick_up(inst: Instrument) -> void:
	held_instrument = inst
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	GameState.set_held(inst)
	_play_voice(inst.instrument_id)


func _play_voice(id: String) -> void:
	# Plays assets/audio/<id>.wav if present; silent otherwise (audio TBD).
	var path := "res://assets/audio/%s.wav" % id
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStream:
		voice.stream = stream
		voice.play()


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
