class_name TableSlot
extends Area3D
## 一个放置目标：Mayo 槽位（按 slot_index）/ back table 分区（按 category）/ 自由格（accept_any）。

@export var slot_index: int = -1
@export var category: String = ""
@export var accept_any: bool = false
var occupied: bool = false
var current_instrument: Instrument = null

@onready var highlight: Sprite3D = $Highlight

var _hl: SlotHighlight


func _ready() -> void:
	highlight.visible = false
	_hl = SlotHighlight.new(highlight)
	GameState.held_changed.connect(_on_held_changed)


func can_accept(inst: Instrument) -> bool:
	if inst == null or inst.def == null:
		return false
	if accept_any:
		return true
	if category != "":
		return inst.def.category == category
	return inst.def.slot_index == slot_index


func show_place_highlight() -> void:
	_hl.show_place()


func hide_highlight() -> void:
	_hl.hide()


func set_feedback(correct: bool) -> void:
	_hl.feedback(correct)


func clear_feedback() -> void:
	_hl.hide()


func _on_held_changed(inst) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		hide_highlight()
		return
	if inst != null and can_accept(inst) and not occupied:
		show_place_highlight()
	else:
		hide_highlight()
