extends Node
## Pickup system (prep phase): instruments are scattered carelessly on the
## back table ("someone left a mess"); pick each one up and organize it onto
## its Mayo slot (sequence order, hard slots). Prep-only scene.

const SNAP_DIST := 0.08

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var held_parent: Node3D = get_parent().get_node("HeldParent")
@onready var slots_parent: Node3D = get_parent().get_node("MayoStand/SlotsParent")
@onready var voice: AudioStreamPlayer = get_parent().get_node("Voice")

var held_instrument: Instrument = null

# 右键取消：记录拿起前的出处，cancel 时原样放回。
var _pickup_origin: Node = null
var _pickup_global := Vector3.ZERO
var _pickup_rot := Vector3.ZERO


func _ready() -> void:
	player.interact_pressed.connect(_on_interact)
	player.inspect_pressed.connect(_on_inspect)


func _process(_delta: float) -> void:
	if held_instrument != null:
		var target: Vector3 = player.get_cursor_point() + Vector3(0, 0, 0)
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
	# Prep 专用场景：不再判断阶段。
	if held_instrument == null:
		var inst := player.get_cursor_instrument() as Instrument
		if inst != null and inst.state == Instrument.State.IN_TRAY:
			_pick_up(inst)
	else:
		var hit: Node = player.get_cursor_slot()
		if hit is TableSlot and not hit.occupied \
				and held_instrument.def.slot_index < 6:
			_place_in_slot(hit as TableSlot)
		elif hit is BackZone and held_instrument.def.slot_index >= 6:
			_place_in_zone(hit as BackZone)


func _on_inspect() -> void:
	# 右键：拿着器械时取消拾取、放回原处；没拿就不处理。
	if held_instrument != null:
		cancel_pickup()


func cancel_pickup() -> void:
	## 右键取消：把拿起的器械原样放回散落台上原来的位置。
	var inst: Instrument = held_instrument
	if inst == null:
		return
	held_instrument = null
	inst.set_state(Instrument.State.IN_TRAY)
	inst.reparent(_pickup_origin)
	inst.global_position = _pickup_global
	inst.rotation_degrees = _pickup_rot
	inst.collision_layer = 1
	inst.freeze = true
	GameState.set_held(null)
	Sfx.play("instrument_pick")


func _pick_up(inst: Instrument) -> void:
	_pickup_origin = inst.get_parent()
	_pickup_global = inst.global_position
	_pickup_rot = inst.rotation_degrees
	held_instrument = inst
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = Vector3(15.0, 90.0, 0.0)
	GameState.set_held(inst)
	Sfx.play("instrument_pick")
	Util.play_voice(voice, inst.instrument_id, "instruments")


func _place_in_slot(slot: TableSlot) -> void:
	var inst: Instrument = held_instrument
	if slot.can_accept(inst):
		held_instrument = null
		inst.set_state(Instrument.State.IN_SLOT)
		inst.reparent(slot)
		inst.position = Vector3(0, 0.01, 0)
		inst.rotation_degrees = Vector3(0, 90, 0)   # 保持“竖着”，别变横
		inst.collision_layer = 1
		slot.occupied = true
		slot.current_instrument = inst
		Sfx.play("slot_correct")
		GameState.set_held(null)
		GameState.prep_correct += 1
		GameState.prep_item_secured.emit(inst.instrument_id)
		GameState.score_updated.emit()
		if GameState.prep_correct + GameState.prep_back_correct >= ProcedureData.total_instances():
			GameState.start_countdown()
	else:
		slot.set_feedback(false)
		Sfx.play("slot_wrong")
		inst.play_reject()


func _place_in_zone(bzone: BackZone) -> void:
	## Prep: instruments that live on the back table (slot_index >= 6) are
	## organized into their category zones instead of mayo slots.
	var inst: Instrument = held_instrument
	if bzone.can_accept(inst) and not bzone.is_full():
		held_instrument = null
		bzone.place_instrument(inst)
		inst.collision_layer = 1
		bzone.set_feedback(true)
		GameState.set_held(null)
		Sfx.play("slot_correct")
		GameState.prep_back_correct += 1
		GameState.prep_back_item_secured.emit(inst.instrument_id)
		GameState.score_updated.emit()
		if GameState.prep_correct + GameState.prep_back_correct >= ProcedureData.total_instances():
			GameState.start_countdown()
	else:
		bzone.set_feedback(false)
		Sfx.play("slot_wrong")
		inst.play_reject()
