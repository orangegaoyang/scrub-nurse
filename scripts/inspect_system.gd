extends Node
class_name InspectSystem
## Inspect mode: brings a 3D item to a fixed point in front of the (fixed)
## camera so the player can rotate it with the mouse and look at it from any
## side. Used by the prep phase (right-click an instrument) and the intro
## (the ID badge is presented up close before flying to the UI).
##
## Controls while inspecting: drag = rotate, right-click or Esc = exit.
## auto_restore = true (prep): the item snaps back to where it came from.
## auto_restore = false (intro): the item is left at the inspect pose so the
## caller can tween it onward (e.g. badge -> top-left UI).

signal exited

@onready var anchor: Node3D = get_parent().get_node("Camera3D/InspectAnchor")

var _item: Node3D = null
var _orig_parent: Node3D = null
var _orig_global := Transform3D.IDENTITY
var _enter_tween: Tween = null
var _dragging: bool = false

var auto_restore: bool = true


func is_inspecting() -> bool:
	return _item != null


func inspect(item: Node3D) -> void:
	if _item != null or item == null:
		return
	_item = item
	_orig_parent = item.get_parent()
	_orig_global = item.global_transform
	item.reparent(anchor)  # keeps global transform; now anchored to camera
	if _enter_tween and _enter_tween.is_valid():
		_enter_tween.kill()
	_enter_tween = create_tween()
	_enter_tween.set_parallel(true)
	_enter_tween.tween_property(item, "position", Vector3.ZERO, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_enter_tween.tween_property(item, "rotation", Vector3.ZERO, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _release() -> void:
	var item := _item
	_item = null
	_dragging = false
	if _enter_tween and _enter_tween.is_valid():
		_enter_tween.kill()
	if item == null:
		exited.emit()
		return
	var gt := item.global_transform
	item.reparent(_orig_parent)
	item.global_transform = _orig_global if auto_restore else gt
	exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _item == null:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_release()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_item.rotate_y(deg_to_rad(-event.relative.x * 0.4))
		_item.rotate_x(deg_to_rad(-event.relative.y * 0.4))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_release()
