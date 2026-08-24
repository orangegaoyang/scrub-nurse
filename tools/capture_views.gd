extends Node
## Visual capture harness: runs the real main scene with rendering, drives the
## systems to key states, and saves viewport screenshots to tools/captures/
## for offline inspection. Run WINDOWED (needs a real renderer):
##   godot --path . res://tools/capture_views.tscn
## States captured: prep double-table view, surgery mayo view (after the
## push-turn transition), neutral-zone deposit, back-table view before/after
## the first return, and the Level II free-cell mayo.

const MAIN := preload("res://scenes/main.tscn")
const CAPTURE_DIR := "res://tools/captures"

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	GameState.selected_surgery = {"procedure": "Craniotomy", "level": 3}  # S3: full set
	main = MAIN.instantiate()
	add_child(main)
	_run()


func _run() -> void:
	await Util.wait(3.4)  # entrance zoom (~2.5s) + scatter settle (0.5s)
	await _capture("prep_view")

	# Complete prep programmatically (scattered back table -> mayo slots /
	# back zones), then start surgery and wait out the transition.
	var pickup: Node = main.get_node("PickupSystem")
	for inst in _instruments_with_state(Instrument.State.IN_TRAY):
		pickup._pick_up(inst)
		if inst.def.slot_index < 6:
			pickup._place_in_slot(_slot_for(inst.def.slot_index))
		else:
			pickup._place_in_zone(_zone_for(inst.def.category))
	GameState.start_surgery()
	GameState.surgeon_line_start.emit()  # acknowledge the intro hint
	await Util.wait(1.2)
	await _capture("surgery_mayo_start")

	# First demand -> deliver scalpel -> wait for the neutral-zone deposit.
	var surgeon: Node = main.get_node("Surgeon")
	await _wait_until(func(): return surgeon.is_demanding(), 8.0)
	var surgery: Node = main.get_node("SurgerySystem")
	var scalpel := _find_state("scalpel", Instrument.State.ON_MAYO)
	if scalpel != null:
		surgery._pick_up(scalpel)
		surgery._deliver(scalpel)
	await _wait_until(func(): return _find_state("scalpel", Instrument.State.IN_ZONE) != null, 10.0)
	await Util.wait(0.4)
	await _capture("surgery_zone_deposit")

	# Back view before/after placing the finished scalpel on the cutting zone.
	main.switch_view(true)
	await Util.wait(0.6)
	await _capture("surgery_back_empty")
	var zinst := _find_state("scalpel", Instrument.State.IN_ZONE)
	if zinst != null:
		surgery._pick_up(zinst)
		surgery._place_in_zone(_zone_for("cutting"))
	await Util.wait(0.5)
	await _capture("surgery_back_filled")

	# Tier-2 free cells: bump familiarity, re-enter surgery (transition runs
	# again and lands on the mayo view), capture the free-cell mayo.
	PlayerProfile.add_surgery_result(GameState.current_procedure_id(), 5)
	GameState.current_phase = GameState.Phase.SURGERY
	GameState.surgeon_line_start.emit()
	await Util.wait(2.6)
	await _capture("surgery_free_cells")
	get_tree().quit()


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [CAPTURE_DIR, shot_name])
	print("captured ", shot_name)


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t: float = 0.0
	while t < timeout:
		if cond.call():
			return true
		await Util.wait(0.1)
		t += 0.1
	return false


func _all_instruments() -> Array:
	var out: Array = []
	_collect(main, out)
	return out


func _collect(n: Node, out: Array) -> void:
	if n is Instrument:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _instruments_with_state(state: int) -> Array:
	var out: Array = []
	for inst in _all_instruments():
		if inst.state == state:
			out.append(inst)
	return out


func _find_state(id: String, state: int) -> Instrument:
	for inst in _all_instruments():
		if inst.instrument_id == id and inst.state == state:
			return inst
	return null


func _zone_for(cat: String) -> BackZone:
	for bz in main.get_node("BackTableZones").get_children():
		if bz is BackZone and bz.category == cat:
			return bz
	return null


func _slot_for(index: int) -> TableSlot:
	for c in main.get_node("MayoStand/SlotsParent").get_children():
		var slot := c as TableSlot
		if slot != null and slot.slot_index == index:
			return slot
	return null
