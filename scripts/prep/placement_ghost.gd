class_name PlacementGhost
extends Node3D
## 放置幽灵：手持器械时，在 Mayo 目标槽位上显示的「同形状灰色半透明轮廓」，
## 用来提示这件器械该放在哪。配有 pop-in 出场 + 透明度/缩放呼吸动效吸引注意。
## 关闭碰撞、名称，纯视觉提示；由 TableSlot 在 held_changed 时显示/隐藏。

const BASE_COLOR := Color(0.78, 0.80, 0.83, 0.26)
const SHOW_TIME := 0.22
const PULSE_TIME := 0.6

var _mat: StandardMaterial3D
var _pulse: Tween = null
var _scale_pulse: Tween = null


func setup(instrument_id: String) -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = BASE_COLOR
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 有真实模型就实物轮廓；没有再退回占位盒体。
	if Instrument.MODELS.has(instrument_id):
		var model: Node3D = Instrument.MODELS[instrument_id].instantiate()
		_apply_material(model)
		add_child(model)
	else:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.04, 0.25)
		mi.mesh = box
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	_play()


func fade_out() -> void:
	## 收起：停掉动效，缩没后释放。
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if _scale_pulse != null:
		_scale_pulse.kill()
		_scale_pulse = null
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(queue_free)


func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_apply_material(c)


func _play() -> void:
	visible = true
	scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, SHOW_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mat, "albedo_color:a", 0.36, 0.3)
	tw.tween_callback(_start_pulse)


func _start_pulse() -> void:
	# 透明度呼吸
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_mat, "albedo_color:a", 0.16, PULSE_TIME).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_mat, "albedo_color:a", 0.36, PULSE_TIME).set_ease(Tween.EASE_IN_OUT)
	# 轻微缩放呼吸（不同属性，可与透明度同步脉动）
	_scale_pulse = create_tween().set_loops()
	_scale_pulse.tween_property(self, "scale", Vector3.ONE * 1.08, PULSE_TIME).set_ease(Tween.EASE_IN_OUT)
	_scale_pulse.tween_property(self, "scale", Vector3.ONE * 0.94, PULSE_TIME).set_ease(Tween.EASE_IN_OUT)
