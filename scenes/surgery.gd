extends Node3D
## Surgery scene. On direct hand-off from the prep check-list
## (GameState.enter_surgery_direct), bring the mayo up at the origin (0,0,0) —
## where the invisible placeholder sits — and seat the arranged instruments
## into its slots. Otherwise it's a plain scene that fades in.

const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

@onready var mayo: Node3D = $MayoStand


func _ready() -> void:
	var direct := GameState.enter_surgery_direct
	GameState.enter_surgery_direct = false
	if direct:
		_enter_surgery()
		Transition.fade_in_from_white(0.5)  # reveal out of the button's white flash
	else:
		await Transition.fade_in()


func _enter_surgery() -> void:
	# The mayo placeholder is hidden; show it at (0,0,0) and re-seat the
	# instruments the player organized in prep so the surgical tray is ready.
	ProcedureData.reload_for_selected()
	mayo.visible = true
	mayo.position = Vector3.ZERO
	mayo.rotation = Vector3.ZERO
	_seat_instruments()
	GameState.start_surgery()


func _seat_instruments() -> void:
	var slots: Array[TableSlot] = []
	for c in mayo.get_node("SlotsParent").get_children():
		if c is TableSlot:
			slots.append(c)
	# Spawn into a throwaway holder, then move each into its slot. Back-table
	# items (slot_index >= 6) have no mayo slot in this WIP scene, so they're
	# laid flat on the tray rather than dropped.
	var holder := Node3D.new()
	add_child(holder)
	for id in ProcedureData.instrument_order:
		var inst: Instrument = INSTRUMENT_SCENE.instantiate()
		holder.add_child(inst)
		inst.setup(id)
		var idx: int = inst.def.slot_index
		if idx < 6:
			var target: TableSlot = null
			for s in slots:
				if s.slot_index == idx:
					target = s
					break
			if target != null:
				_place_in_slot(inst, target)
				continue
		_place_on_tray(inst)
	holder.queue_free()


func _place_in_slot(inst: Instrument, slot: TableSlot) -> void:
	inst.set_state(Instrument.State.IN_SLOT)
	inst.reparent(slot)
	inst.position = Vector3(0, 0.01, 0)
	inst.rotation_degrees = Vector3(0, 90, 0)  # upright, long axis along X
	inst.collision_layer = 1
	inst.freeze = true
	slot.occupied = true
	slot.current_instrument = inst


func _place_on_tray(inst: Instrument) -> void:
	inst.set_state(Instrument.State.ON_MAYO)
	inst.reparent(mayo)
	inst.position = Vector3(0, 0.84, 0)
	inst.rotation_degrees = Vector3(0, 90, 0)
	inst.collision_layer = 1
	inst.freeze = true
