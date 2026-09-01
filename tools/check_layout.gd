extends Node
## Headless layout check for the operating-room integration: prints the
## projection of every gameplay anchor through the three cameras so the
## framing can be verified without a renderer. Run:
##   godot --headless --path . res://tools/check_layout.tscn

const MAIN := preload("res://scenes/main.tscn")

var main: Node


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	GameState.selected_surgery = {"procedure": "Craniotomy", "level": 3}
	main = MAIN.instantiate()
	add_child(main)
	await Util.wait(1.0)

	var cam_prep: Camera3D = main.get_node("CameraPrep")
	var cam_mayo: Camera3D = main.get_node("CameraMayo")
	var cam_back: Camera3D = main.get_node("CameraBackTable")
	var mayo: Node3D = main.get_node("MayoStand")
	var surgeon: Node3D = main.get_node("Surgeon")
	var room: Node3D = main.get_node("Room")

	print("room children: ", room.get_children().map(func(n): return n.name))

	print("== PREP frame ==")
	_proj(cam_prep, "backtable", main.get_node("Backtable/BackTableVisual/backtable").global_position)
	for z in main.get_node("Backtable/BackTableZones").get_children():
		_proj(cam_prep, "zone " + z.name, z.global_position)
	_proj(cam_prep, "mayo tray (prep)", mayo.global_position)
	for c in mayo.get_node("SlotsParent").get_children():
		if c is TableSlot:
			_proj(cam_prep, "slot " + str((c as TableSlot).slot_index), c.global_position)

	print("== MAYO frame (surgery pose) ==")
	mayo.global_position = Vector3(2.06, 0.306, 0.3)
	var zone: Node3D = main.get_node("NeutralZone")
	_proj(cam_mayo, "tray center", mayo.global_position)
	_proj(cam_mayo, "tray L edge", mayo.global_position + Vector3(-0.30, 0.85, 0))
	_proj(cam_mayo, "tray R edge", mayo.global_position + Vector3(0.30, 0.85, 0))
	_proj(cam_mayo, "tray F edge", mayo.global_position + Vector3(0, 0.85, 0.235))
	_proj(cam_mayo, "tray B edge", mayo.global_position + Vector3(0, 0.85, -0.235))
	_proj(cam_mayo, "neutral zone", zone.global_position)
	for c in mayo.get_node("SlotsParent").get_children():
		if c is TableSlot:
			_proj(cam_mayo, "slot " + str((c as TableSlot).slot_index), c.global_position)
	var pivot: Node3D = surgeon.get_node("HandPivot")
	_proj(cam_mayo, "hand EXTENDED", pivot.global_position)
	_proj(cam_mayo, "hand TARGET(1.76,1.28,0.33)", Vector3(1.76, 1.28, 0.33))
	_proj(cam_mayo, "hand RETRACTED", Vector3(2.5, 1.65, 0.25))
	_proj(cam_mayo, "bed L", Vector3(-0.98, 1.0, 0.22))
	_proj(cam_mayo, "bed R", Vector3(1.76, 1.0, 0.22))
	_proj(cam_mayo, "bed foot", Vector3(0.39, 1.0, 0.6))
	_proj(cam_mayo, "bed head", Vector3(0.39, 1.0, -0.15))
	_proj(cam_mayo, "back wall", Vector3(0.9, 1.8, -1.77))
	_proj(cam_mayo, "right wall", Vector3(2.39, 1.8, 0.3))
	_proj(cam_mayo, "left wall", Vector3(-1.6, 1.8, 0.3))
	_proj(cam_mayo, "light", Vector3(0.14, 2.0, 0.22))

	print("== BACK frame (Q view) ==")
	for z in main.get_node("Backtable/BackTableZones").get_children():
		_proj(cam_back, "zone " + z.name, z.global_position)
	_proj(cam_back, "backtable", main.get_node("Backtable/BackTableVisual/backtable").global_position)
	get_tree().quit()


func _proj(cam: Camera3D, label: String, p: Vector3) -> void:
	var in_frustum: bool = cam.is_position_in_frustum(p)
	var s: Vector2 = cam.unproject_position(p)
	print("  %-28s world=%s in=%s screen=(%.0f, %.0f)" % [
		label, p.round() if false else _fmt(p), in_frustum, s.x, s.y])


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
