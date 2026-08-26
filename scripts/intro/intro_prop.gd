class_name IntroProp
extends Node3D
## A decoration prop on the intro desk. Owns its idle micro-animations: a
## faint mouse parallax (`parallax_px` screen pixels of travel at full
## cursor swing, 0 disables it). Every prop also answers `shake()` — the tiny
## whole-desk nudge the intro scene fires when the schedule paper lands on
## the table.

@export var parallax_px: float = 0.0  # 0 = parallax off

const SHAKE_UP := 0.0012  # ≈2 px of lift at desk depth
const SHAKE_HOLD := 0.08
const SHAKE_SETTLE := 0.14

var _camera: Camera3D
var _base_pos: Vector3
var _plane_y: float
var _par: Vector3 = Vector3.ZERO
var _shake_off: Vector3 = Vector3.ZERO
var _shake_tw: Tween


func _ready() -> void:
	add_to_group("desk_prop")
	_base_pos = position
	_plane_y = global_position.y


func setup(camera: Camera3D) -> void:
	_camera = camera


func _process(delta: float) -> void:
	if _camera != null and parallax_px > 0.0:
		_par = _par.lerp(
			Util.parallax_offset(_camera, _plane_y, parallax_px),
			clampf(delta * 8.0, 0.0, 1.0))
	position = _base_pos + _par + _shake_off


func shake() -> void:
	# A barely-there hop: the desk gets bumped as the paper lands.
	if _shake_tw:
		_shake_tw.kill()
	_shake_off = Vector3.ZERO
	_shake_tw = create_tween()
	_shake_tw.tween_method(_set_shake_y, 0.0, SHAKE_UP, SHAKE_HOLD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shake_tw.tween_method(_set_shake_y, SHAKE_UP, 0.0, SHAKE_SETTLE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_shake_y(v: float) -> void:
	_shake_off.y = v
