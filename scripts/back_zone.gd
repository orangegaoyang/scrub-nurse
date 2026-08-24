class_name BackZone
extends Area3D
## A back-table category zone (切割 | 钳夹 | 抓持 | 缝合 | 敷料). Accepts any
## instrument of its category into one of its anchor spots (capacity = how many
## instruments of that category exist). Wrong category bounces. Category zones
## are ALWAYS hard-judged — they are the profession's bottom line, not a
## training wheel.

@export var category: String = ""
@export var frame_size: Vector2 = Vector2(0.2, 0.24)
# First-surgery prep: zones start dimmed (set in the editor) and light up at
# the first finished-instrument return. The alpha values are editor-tunable.
@export var dimmed: bool = true:
	set(v):
		dimmed = v
		_apply_dim()
@export var dim_alpha: float = 0.0:  # 0 = fully hidden until the first return
	set(v):
		dim_alpha = v
		_apply_dim()
@export var lit_alpha: float = 0.35:
	set(v):
		lit_alpha = v
		_apply_dim()

const COLOR_PLACE := Color(1, 1, 1, 0.9)
const COLOR_OK := Color(0.4, 0.9, 0.45, 1)
const COLOR_BAD := Color(0.95, 0.3, 0.3, 1)

var current_instruments: Array[Instrument] = []

var highlight: Sprite3D
var _anchors: Array[Node3D] = []
var _hide_tw: Tween = null
var _plate: MeshInstance3D = null


func _ready() -> void:
	_build_highlight()
	_build_plate()
	for c in get_children():
		if c is Node3D and c.name.begins_with("Anchor"):
			_anchors.append(c)
	GameState.held_changed.connect(_on_held_changed)


func get_capacity() -> int:
	## How many instruments of this category the procedure uses, clamped to
	## the available anchor spots. Computed lazily: the procedure data loads
	## AFTER child _ready runs.
	var n: int = 0
	for id in ProcedureData.instrument_order:
		if ProcedureData.get_instrument(id).category == category:
			n += 1
	return clampi(n, 1, _anchors.size())


func can_accept(inst: Instrument) -> bool:
	return inst != null and inst.def != null and inst.def.category == category


func is_full() -> bool:
	return current_instruments.size() >= get_capacity()


func place_instrument(inst: Instrument) -> bool:
	## Snap `inst` into a free anchor spot. Caller already checked can_accept.
	for anchor in _anchors:
		if anchor.get_child_count() == 0:
			inst.set_state(Instrument.State.IN_SLOT)
			inst.reparent(anchor)
			inst.transform = Transform3D.IDENTITY
			inst.position = Vector3(0, 0.02, 0)
			inst.collision_layer = 1
			inst.freeze = true
			current_instruments.append(inst)
			return true
	return false


func remove_instrument(inst: Instrument) -> void:
	current_instruments.erase(inst)


func show_place_highlight() -> void:
	_kill_hide()
	if highlight.visible and highlight.modulate == COLOR_PLACE:
		return
	_tint(COLOR_PLACE)
	_pop_in()


func hide_highlight() -> void:
	if highlight == null or not highlight.visible:
		return
	if _hide_tw != null and _hide_tw.is_valid():
		return
	_hide_tw = create_tween()
	_hide_tw.tween_property(highlight, "scale", Vector3.ZERO, 0.12)
	_hide_tw.tween_callback(func(): highlight.visible = false)


func set_feedback(correct: bool) -> void:
	_kill_hide()
	_tint(COLOR_OK if correct else COLOR_BAD)
	_pop_in()
	if not correct:
		await Util.wait(0.3)
		hide_highlight()


func clear_feedback() -> void:
	hide_highlight()


func _on_held_changed(inst) -> void:
	# Prep highlights zones for the instruments that live on the back table
	# (slot_index >= 6); surgery drives highlights per-frame.
	if GameState.current_phase != GameState.Phase.PREP:
		hide_highlight()
		return
	if inst != null and inst.def != null and inst.def.slot_index >= 6 \
			and can_accept(inst) and not is_full():
		show_place_highlight()
	else:
		hide_highlight()


func _build_highlight() -> void:
	highlight = Sprite3D.new()
	var tex_w := 80
	var tex_h := int(round(tex_w * frame_size.y / frame_size.x))
	highlight.texture = _make_frame_texture(Vector2i(tex_w, tex_h))
	highlight.pixel_size = frame_size.x / float(tex_w)
	# Lie flat on the tabletop like the mayo slot frames.
	highlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	highlight.position = Vector3(0, 0.05, 0)
	highlight.no_depth_test = true
	highlight.scale = Vector3.ZERO
	highlight.visible = false
	add_child(highlight)


func _build_plate() -> void:
	## A faint flat plate so each category region reads even when empty-handed.
	_plate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(frame_size.x + 0.03, 0.01, frame_size.y + 0.03)
	_plate.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 0.9, dim_alpha if dimmed else lit_alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plate.material_override = mat
	_plate.position = Vector3(0, -0.045, 0)
	add_child(_plate)


func set_dimmed(on: bool) -> void:
	## The surgery system lights the zones up at the first finished-instrument
	## return; the initial dimmed state comes from the scene/editor.
	dimmed = on


func _apply_dim() -> void:
	if _plate == null:
		return
	var mat := _plate.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(0.75, 0.85, 0.9, dim_alpha if dimmed else lit_alpha)


func _pop_in() -> void:
	_kill_hide()
	highlight.visible = true
	highlight.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(highlight, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _kill_hide() -> void:
	if _hide_tw != null and _hide_tw.is_valid():
		_hide_tw.kill()
	_hide_tw = null


func _tint(color: Color) -> void:
	highlight.modulate = color


func _make_frame_texture(size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var t := 2
	img.fill_rect(Rect2i(t, t, size.x - 2 * t, size.y - 2 * t), Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
