class_name CameraDirector
extends RefCounted
## 相机调度：开场推镜、切入手术的跟拍、前后视角切换。
## 空间点位全部来自主场景的 DirectorMarkers 标记，在编辑器里拖动即可调整，
## 代码里不写任何硬编码坐标。

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

var _surgery_pos: Marker3D
var _entrance_focus: Marker3D

var _on_back_view := false
var _mayo_rest_pos := Vector3.ZERO
var _mayo_rest_rot := Vector3.ZERO
var _mayo_rest_fov := 38.2
var _prep_rest_fov := 64.5


func _init(prep: Camera3D, mayo_cam: Camera3D, back_cam: Camera3D, mayo_stand: Node3D,
		zone: Node3D, surgeon: Node3D, voice: AudioStreamPlayer,
		markers: Node3D) -> void:
	_prep = prep
	_mayo_cam = mayo_cam
	_back_cam = back_cam
	_mayo_stand = mayo_stand
	_zone = zone
	_surgeon = surgeon
	_voice = voice
	_surgery_pos = markers.get_node("MayoSurgeryPos")
	_entrance_focus = markers.get_node("EntranceFocus")


func prepare() -> void:
	## 相机的朝向和位置全部来自编辑器；这里只记下休整位姿并把隐藏的相机打开。
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
	var focus := _entrance_focus.global_position
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
	# 推车两段滚动：先沿墙横移（目标 x、保持当前 y/z），再推向床边标记点。
	var start := _mayo_stand.global_position
	var target := _surgery_pos.global_position
	var mid := Vector3(target.x, start.y, start.z)
	var roll := _mayo_stand.create_tween()
	roll.tween_property(_mayo_stand, "global_position", mid, ROLL_SIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	roll.tween_property(_mayo_stand, "global_position", target, ROLL_FWD_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
