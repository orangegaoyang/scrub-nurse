class_name BackZone
extends Area3D
## back table 分区（切割/钳夹/抓持/缝合/敷料）。同类别器械放进去，错类别弹回。

@export var category: String = ""
@export var frame_size: Vector2 = Vector2(0.2, 0.24)
@export var dimmed: bool = true:
	set(v):
		dimmed = v
		_apply_dim()
@export var dim_alpha: float = 0.0:
	set(v):
		dim_alpha = v
		_apply_dim()
@export var lit_alpha: float = 0.35:
	set(v):
		lit_alpha = v
		_apply_dim()

var current_instruments: Array[Instrument] = []

var highlight: Sprite3D
var _hl: SlotHighlight
var _plate: MeshInstance3D = null


func _ready() -> void:
	_build_highlight()
	_hl = SlotHighlight.new(highlight)
	_build_plate()
	GameState.held_changed.connect(_on_held_changed)


func get_capacity() -> int:
	## 该类别器械的总件数（含多件备用），也就是这个分区要收容的数量。
	var n: int = 0
	for id in ProcedureData.instrument_order:
		var def = ProcedureData.get_instrument(id)
		if def.category == category:
			n += def.count
	return n


func can_accept(inst: Instrument) -> bool:
	return inst != null and inst.def != null and inst.def.category == category


func is_full() -> bool:
	return current_instruments.size() >= get_capacity()


func place_instrument(inst: Instrument) -> bool:
	## 自由摆放：器械留在玩家松开鼠标的位置，钳制在分区框内，重叠允许。
	if is_full():
		return false
	inst.set_state(Instrument.State.IN_SLOT)
	inst.reparent(self)
	var local := inst.position
	local.x = clampf(local.x, -frame_size.x * 0.5, frame_size.x * 0.5)
	local.z = clampf(local.z, -frame_size.y * 0.5, frame_size.y * 0.5)
	local.y = 0.07
	inst.position = local
	inst.rotation_degrees = Vector3.ZERO
	inst.collision_layer = 1
	inst.freeze = true
	current_instruments.append(inst)
	return true


func remove_instrument(inst: Instrument) -> void:
	current_instruments.erase(inst)


func show_place_highlight() -> void:
	_hl.show_place()


func hide_highlight() -> void:
	_hl.hide()


func set_feedback(correct: bool) -> void:
	_hl.feedback(correct)


func clear_feedback() -> void:
	_hl.hide()


func _on_held_changed(inst) -> void:
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
	highlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	highlight.position = Vector3(0, 0.05, 0)
	highlight.no_depth_test = true
	highlight.scale = Vector3.ZERO
	highlight.visible = false
	add_child(highlight)


func _build_plate() -> void:
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
	dimmed = on


func _apply_dim() -> void:
	if _plate == null:
		return
	var mat := _plate.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(0.75, 0.85, 0.9, dim_alpha if dimmed else lit_alpha)


func _make_frame_texture(size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var t := 2
	img.fill_rect(Rect2i(t, t, size.x - 2 * t, size.y - 2 * t), Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
