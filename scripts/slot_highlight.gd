class_name SlotHighlight
extends RefCounted
## 槽位/分区共用的白色框反馈：放置提示、对错变色、缩放弹出与淡出。

const COLOR_PLACE := Color(1, 1, 1, 0.9)
const COLOR_OK := Color(0.4, 0.9, 0.45, 1)
const COLOR_BAD := Color(0.95, 0.3, 0.3, 1)

var _sprite: Sprite3D
var _hide_tw: Tween = null


func _init(sprite: Sprite3D) -> void:
	_sprite = sprite


func show_place() -> void:
	_kill_hide()
	if _sprite.visible and _sprite.modulate == COLOR_PLACE:
		return
	_tint(COLOR_PLACE)
	_pop()


func feedback(ok: bool) -> void:
	_kill_hide()
	_tint(COLOR_OK if ok else COLOR_BAD)
	_pop()
	if not ok:
		await Util.wait(0.3)
		hide()


func hide() -> void:
	if _sprite == null or not _sprite.visible:
		return
	if _hide_tw != null and _hide_tw.is_valid():
		return
	_hide_tw = _sprite.create_tween()
	_hide_tw.tween_property(_sprite, "scale", Vector3.ZERO, 0.12)
	_hide_tw.tween_callback(func(): _sprite.visible = false)


func _pop() -> void:
	_sprite.visible = true
	_sprite.scale = Vector3.ZERO
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "scale", Vector3.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _tint(color: Color) -> void:
	_sprite.modulate = color


func _kill_hide() -> void:
	if _hide_tw != null and _hide_tw.is_valid():
		_hide_tw.kill()
	_hide_tw = null
