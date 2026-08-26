class_name CameraDirector
extends RefCounted
## 相机调度：开场推镜、切入手术的跟拍、前后视角切换。

const MAYO_SURGERY_POS := Vector3(2.06, 0.197, 0.3)
const MAYO_ROLL_MID := Vector3(2.06, 0.197, -1.23)
const ROLL_SIDE_TIME := 0.5
const ROLL_FWD_TIME := 0.9
const DOLLY_TIME := 1.4

const ENTRANCE_TIME := 2.5
const ENTRANCE_FOV_FACTOR := 0.55
const ENTRANCE_BACK := 0.3
const ENTRANCE_VOICE := "surgery_start"
const ENTRANCE_VOICE_DELAY := 0.4

var _prep: Camera3D
var _mayo_cam: Camera3D
var _back_cam: Camera3D
var _mayo_stand: Node3D
var _zone: Node3D
var _surgeon: Node3D
var _voice: AudioStreamPlayer

var _on_back_view := false
var _mayo_rest_pos := Vector3.ZERO
var _mayo_rest_rot := Vector3.ZERO
var _mayo_rest_fov := 38.2
var _prep_rest_fov := 64.5


func _init(prep: Camera3D, mayo_cam: Camera3D, back_cam: Camera3D, mayo_stand: Node3D,
		zone: Node3D, surgeon: Node3D, voice: AudioStreamPlayer) -> void:
	_prep = prep
	_mayo_cam = mayo_cam
	_back_cam = back_cam
	_mayo_stand = mayo_stand
	_zone = zone
	_surgeon = surgeon
	_voice = voice


func prepare() -> void:
	## 对准目标、记下休整位姿、把编辑器里隐藏的相机打开。
	_mayo_cam.look_at(Vector3(1.7, 1.02, 0.3))
	_back_cam.look_at(Vector3(0.9, 0.94, -1.2))
	_mayo_rest_pos = _mayo_cam.position
	_mayo_rest_rot = _mayo_cam.rotation_degrees
	_mayo_rest_fov = _mayo_cam.fov
	_prep_rest_fov = _prep.fov
	_prep.visible = true
	_mayo_cam.visible = true
	_back_cam.visible = true


func entrance_zoom() -> void:
	## 开场从深处收紧的镜头滑回准备位，然后播一句开场白。
	var rest_pos := _prep.global_position
	var focus := Vector3(1.255, 1.0, -1.21)
	var dir := (rest_pos - focus).normalized()
	_prep.global_position = rest_pos + dir * ENTRANCE_BACK
	_prep.fov = _prep_rest_fov * ENTRANCE_FOV_FACTOR
	var tw := _prep.create_tween().set_parallel(true)
	tw.tween_property(_prep, "global_position", rest_pos, ENTRANCE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_prep, "fov", _prep_rest_fov, ENTRANCE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await Util.wait(ENTRANCE_VOICE_DELAY)
	Util.play_voice(_voice, ENTRANCE_VOICE)


func is_on_back_view() -> bool:
	return _on_back_view


func toggle_view() -> void:
	_show(not _on_back_view)


func show_mayo_view() -> void:
	if _on_back_view:
		_show(false)


func _show(to_back: bool) -> void:
	_on_back_view = to_back
	if to_back:
		_back_cam.make_current()
	else:
		_mayo_cam.make_current()
	GameState.view_switched.emit()


func push_transition() -> void:
	## 准备 -> 手术的连续镜头：相机跟着 Mayo 推车走到床边。
	_zone.visible = ProcedureData.has_neutral_zone()
	_surgeon.visible = true
	if ProcedureData.has_neutral_zone():
		GameState.hint_changed.emit("用过的器械会放进中立区——及时取走清台", true)
	else:
		GameState.surgeon_line_start.emit()
	_mayo_cam.global_transform = _prep.global_transform
	_mayo_cam.fov = _prep.fov
	_mayo_cam.make_current()
	_on_back_view = false
	var tw := _mayo_cam.create_tween().set_parallel(true)
	tw.tween_property(_mayo_cam, "global_position", _mayo_rest_pos, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_mayo_cam, "rotation_degrees", _mayo_rest_rot, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_mayo_cam, "fov", _mayo_rest_fov, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var roll := _mayo_stand.create_tween()
	roll.tween_property(_mayo_stand, "global_position", MAYO_ROLL_MID, ROLL_SIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	roll.tween_property(_mayo_stand, "global_position", MAYO_SURGERY_POS, ROLL_FWD_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
