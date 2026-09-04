class_name TableSlot
extends Area3D
## 一个放置目标：Mayo 槽位（按 slot_index）/ back table 分区（按 category）/ 自由格（accept_any）。

@export var slot_index: int = -1
@export var category: String = ""
@export var accept_any: bool = false
var occupied: bool = false
var current_instrument: Instrument = null


var _hl: SlotHighlight
var _ghost: PlacementGhost = null


func _ready() -> void:
	GameState.held_changed.connect(_on_held_changed)


func can_accept(inst: Instrument) -> bool:
	if inst == null or inst.def == null:
		return false
	if accept_any:
		return true
	if category != "":
		return inst.def.category == category
	return inst.def.slot_index == slot_index


func set_feedback(correct: bool) -> void:
	## 放置对/错的框反馈。高亮系统重构中尚未接回(_hl 暂为空),先保证调用安全。
	if _hl != null:
		_hl.feedback(correct)


func clear_feedback() -> void:
	if _hl != null:
		_hl.hide()


func _on_held_changed(inst) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		_hide_ghost()
		return
	if inst != null and can_accept(inst) and not occupied:
		_show_ghost(inst)
	else:
		_hide_ghost()



func _show_ghost(inst: Instrument) -> void:
	# Mayo 槽位专用：只对 mayo 器械（slot_index < 6）显示幽灵；back table
	# 器械不在此显示（can_accept 已保证 slot_index 匹配）。
	if inst.def.slot_index >= 6:
		_hide_ghost()
		return
	if _ghost == null:
		_ghost = PlacementGhost.new()
		_ghost.setup(inst.instrument_id)
		add_child(_ghost)
		# 与“放进槽位”时相同的位姿：贴面、转为竖直（长轴沿 X）。
		_ghost.position = Vector3(0, 0.01, 0)
		_ghost.rotation_degrees = Vector3(0, 90, 0)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.fade_out()
		_ghost = null
