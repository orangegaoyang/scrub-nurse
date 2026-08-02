extends Node3D
## Prep-complete board: a flat plane facing the near top-down camera, shown only
## in COUNTDOWN phase. Presents the surgery.PNG artwork, then the finalized
## instrument checklist appearing item-by-item and being checked off, then emits
## list_presented so the UI layer can reveal the "进入手术" button last. When
## res://assets/2D/common/surgery.PNG is absent a solid placeholder card is
## generated; dropping the PNG in later upgrades the board automatically once
## Godot imports it.

signal list_presented()

const SURGERY_IMG := "res://assets/2D/common/surgery.PNG"
const TEXT_COLOR := Color(0.08, 0.10, 0.09)
const DONE_COLOR := Color(0.18, 0.42, 0.20)
const PIXEL_SIZE := 0.0005

@onready var board: MeshInstance3D = $Board
@onready var list_parent: Node3D = $Board/List

var _title: Label3D
var _items: Array[Label3D] = []


func _ready() -> void:
	_apply_texture()
	_build_list()
	board.scale = Vector3.ZERO
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)


func _apply_texture() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _resolve_texture()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	board.material_override = mat


func _resolve_texture() -> Texture2D:
	# Use the real artwork once it has been imported into common/.
	if ResourceLoader.exists(SURGERY_IMG):
		var t = load(SURGERY_IMG)
		if t is Texture2D:
			return t
	return _make_placeholder()


func _make_placeholder() -> Texture2D:
	# A calm clinical card — a clear stand-in until surgery.PNG is provided.
	var img := Image.create(256, 192, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.84, 0.90, 0.89))
	return ImageTexture.create_from_image(img)


func _build_list() -> void:
	_title = _make_label("器械整理完成", 38, Vector3(0.0, 0.08, 0.006))
	list_parent.add_child(_title)

	var top_y := 0.045
	var step := 0.027
	var i := 0
	for id in ProcedureData.demand_sequence:
		var def = ProcedureData.get_instrument(id)
		var unchecked := "%d. %s — %s" % [i + 1, def.name_cn, def.purpose]
		var checked := "✓ %d. %s — %s" % [i + 1, def.name_cn, def.purpose]
		var lbl := _make_label(unchecked, 26, Vector3(0.0, top_y - i * step, 0.006))
		lbl.set_meta("unchecked", unchecked)
		lbl.set_meta("checked", checked)
		list_parent.add_child(lbl)
		_items.append(lbl)
		i += 1


func _make_label(text: String, size: int, pos: Vector3) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.pixel_size = PIXEL_SIZE
	lbl.font_size = size
	# Start invisible so _present() can fade lines in one-by-one. Set the alpha
	# here instead of via a later .text re-assignment, which would regenerate
	# Label3D's glyph texture and leave a blurry ghost.
	lbl.modulate = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.0)
	lbl.outline_size = 2
	lbl.no_depth_test = true
	lbl.horizontal_alignment = 1
	lbl.position = pos
	return lbl


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.COUNTDOWN:
		_present()
	else:
		visible = false


func _present() -> void:
	visible = true
	board.scale = Vector3.ZERO
	# Labels start invisible (alpha 0 set in _make_label) so the cascade can
	# fade them in. Don't re-assign .text here -- regenerating Label3D's glyph
	# texture leaves a blurry ghost ("written twice").
	var tw := create_tween()
	tw.tween_property(board, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3)
	for lbl in _items:
		# Line fades in unchecked (dark), then gets its ✓ and turns green.
		tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
		tw.tween_callback(Callable(self, "_check_item").bind(lbl))
		tw.tween_property(lbl, "modulate", DONE_COLOR, 0.2)
	tw.tween_callback(func(): list_presented.emit())


func _check_item(lbl: Label3D) -> void:
	lbl.text = lbl.get_meta("checked")
