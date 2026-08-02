extends Node3D
## Prep-complete board: a flat plane facing the near top-down camera, shown only
## in COUNTDOWN phase. Pairs the surgery.PNG artwork with the finalized,
## fully-checked instrument checklist. The "进入手术" button lives separately
## in the UI layer (StartButton). When res://assets/2D/common/surgery.PNG is
## absent, a solid placeholder card is generated; dropping the PNG into the
## folder later upgrades the board automatically once Godot imports it.

const SURGERY_IMG := "res://assets/2D/common/surgery.PNG"
const TEXT_COLOR := Color(0.12, 0.14, 0.13)
const DONE_COLOR := Color(0.30, 0.50, 0.30)

@onready var board: MeshInstance3D = $Board
@onready var list_parent: Node3D = $Board/List


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
	var img := Image.create(512, 384, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.84, 0.90, 0.89))
	return ImageTexture.create_from_image(img)


func _build_list() -> void:
	var title := Label3D.new()
	title.text = "器械整理完成"
	title.pixel_size = 0.0006
	title.font_size = 34
	title.modulate = TEXT_COLOR
	title.outline_size = 1
	title.no_depth_test = true
	title.position = Vector3(0.0, 0.17, 0.012)
	list_parent.add_child(title)

	var top_y := 0.10
	var step := 0.048
	var i := 0
	for id in ProcedureData.demand_sequence:
		var def = ProcedureData.get_instrument(id)
		var lbl := Label3D.new()
		lbl.text = "✓ %d. %s — %s" % [i + 1, def.name_cn, def.purpose]
		lbl.pixel_size = 0.0006
		lbl.font_size = 22
		lbl.modulate = DONE_COLOR
		lbl.outline_size = 1
		lbl.no_depth_test = true
		lbl.position = Vector3(0.0, top_y - i * step, 0.012)
		list_parent.add_child(lbl)
		i += 1


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.COUNTDOWN:
		_present()
	else:
		visible = false


func _present() -> void:
	visible = true
	board.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(board, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
