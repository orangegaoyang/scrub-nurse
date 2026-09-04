extends Node3D
## Surgery scene. Bring the mayo up at the origin (0,0,0) — where the invisible
## placeholder sits — seat the instruments the player organized in prep, then
## start the surgery phase. Running the scene directly (F6) does the same, so
## the surgery phase is always playable here: SurgerySystem (pickup/delivery) +
## SurgeonLine (beat-driven demands) are wired as scene nodes, the neutral
## zone / back table show per procedure, and the result card lives in UI.

const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

@onready var mayo: Node3D = $MayoStand
@onready var zone: Node3D = $NeutralZone
@onready var backtable: Node3D = $Backtable


func _ready() -> void:
	GameState.reset()
	ProcedureData.reload_for_selected()
	_enter_surgery()
	Transition.fade_in_from_white(0.5)  # reveal out of the button's white flash


func _enter_surgery() -> void:
	# The mayo placeholder is hidden; show it at (0,0,0) and re-seat the
	# instruments the player organized in prep so the surgical tray is ready.
	mayo.visible = true
	mayo.position = Vector3.ZERO
	mayo.rotation = Vector3.ZERO
	_apply_procedure_visibility()
	_seat_instruments()
	GameState.start_surgery()
	# No HUD hint flow in this scene: kick off the surgeon's line directly.
	# The first demand lands on the next accent beat (a natural count-in).
	GameState.surgeon_line_start.emit()


func _apply_procedure_visibility() -> void:
	zone.visible = ProcedureData.has_neutral_zone()
	backtable.visible = ProcedureData.has_back_table()
	if ProcedureData.has_back_table():
		for c in backtable.get_node("BackTableZones").get_children():
			if c is BackZone:
				(c as BackZone).set_dimmed(false)


func _seat_instruments() -> void:
	var slots: Array[TableSlot] = []
	for c in mayo.get_node("SlotsParent").get_children():
		if c is TableSlot:
			slots.append(c)
	var zones: Array[BackZone] = []
	if backtable.visible:
		for c in backtable.get_node("BackTableZones").get_children():
			if c is BackZone:
				zones.append(c)
	# Spawn into a throwaway holder, then move each into its slot / back-zone.
	# Anything unplaceable is laid flat on the tray as a fallback.
	var holder := Node3D.new()
	add_child(holder)
	for id in ProcedureData.instrument_order:
		var inst: Instrument = INSTRUMENT_SCENE.instantiate()
		holder.add_child(inst)
		inst.setup(id)
		var idx: int = inst.def.slot_index
		if idx < 6:
			var target := _find_slot(slots, idx)
			if target != null:
				_place_in_slot(inst, target)
				continue
		elif not zones.is_empty():
			var bz := _find_zone(zones, inst.def.category)
			if bz != null:
				bz.place_instrument(inst)
				inst.collision_layer = 1
				continue
		_place_on_tray(inst)
	holder.queue_free()


func _find_slot(slots: Array[TableSlot], index: int) -> TableSlot:
	for s in slots:
		if s.slot_index == index:
			return s
	return null


func _find_zone(zones: Array[BackZone], category: String) -> BackZone:
	for z in zones:
		if z.category == category:
			return z
	return null


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
