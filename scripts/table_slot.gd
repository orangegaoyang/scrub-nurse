class_name TableSlot
extends Area3D
## A slot on the instrument table. Accepts the instrument whose slot_index
## matches. While the player holds an instrument, the matching empty slot
## pops a white frame to show where it goes.

@export var slot_index: int = 0
var occupied: bool = false
var current_instrument: Instrument = null

const FRAME_SIZE := Vector2(0.12, 0.10)  # world width x height, must be <= slot pitch (~0.13)
const COLOR_PLACE := Color(1, 1, 1, 0.9)
const COLOR_OK := Color(0.4, 0.9, 0.45, 1)
const COLOR_BAD := Color(0.95, 0.3, 0.3, 1)

var highlight: Sprite3D


func _ready() -> void:
	_build_highlight()
	GameState.held_changed.connect(_on_held_changed)


func can_accept(inst: Instrument) -> bool:
	return inst.def != null and inst.def.slot_index == slot_index


func show_place_highlight() -> void:
	_tint(COLOR_PLACE)
	_pop_in()


func hide_highlight() -> void:
	if highlight and highlight.visible:
		var tw := create_tween()
		tw.tween_property(highlight, "scale", Vector3.ZERO, 0.12)
		tw.tween_callback(func(): highlight.visible = false)


func set_feedback(correct: bool) -> void:
	_tint(COLOR_OK if correct else COLOR_BAD)
	_pop_in()
	if not correct:
		await get_tree().create_timer(0.3).timeout
		hide_highlight()


func clear_feedback() -> void:
	hide_highlight()


func _on_held_changed(inst) -> void:
	# Only the prep phase uses slot placement highlights.
	if GameState.current_phase != GameState.Phase.PREP:
		hide_highlight()
		return
	if inst != null and can_accept(inst) and not occupied:
		show_place_highlight()
	else:
		hide_highlight()


func _build_highlight() -> void:
	highlight = Sprite3D.new()
	# Texture resolution follows the frame's aspect ratio so it stays a
	# rectangle; pixel_size is derived from the width.
	var tex_w := 80
	var tex_h := int(round(tex_w * FRAME_SIZE.y / FRAME_SIZE.x))
	highlight.texture = _make_frame_texture(Vector2i(tex_w, tex_h))
	highlight.pixel_size = FRAME_SIZE.x / float(tex_w)
	highlight.billboard = 1
	highlight.no_depth_test = true
	highlight.scale = Vector3.ZERO
	highlight.visible = false
	add_child(highlight)


func _pop_in() -> void:
	highlight.visible = true
	highlight.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(highlight, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _tint(color: Color) -> void:
	highlight.modulate = color


func _make_frame_texture(size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var t := 5
	img.fill_rect(Rect2i(t, t, size.x - 2 * t, size.y - 2 * t), Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
