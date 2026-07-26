class_name TableSlot
extends Area3D
## A slot on the instrument table. Accepts the instrument whose slot_index matches.
## Shows a flat paper "tag" with the instrument name; feedback tints the tag.

@export var slot_index: int = 0
var occupied: bool = false
var current_instrument: Instrument = null

const TAG_COLOR := Color(0.97, 0.96, 0.92, 1)
const COLOR_OK := Color(0.4, 0.9, 0.45, 1)
const COLOR_BAD := Color(0.95, 0.3, 0.3, 1)

@onready var tag: MeshInstance3D = $Tag
@onready var name_label: Label3D = $Tag/NameLabel


func _ready() -> void:
	# Tag shows the name of the instrument that belongs in this slot.
	var id = ProcedureData.demand_sequence[slot_index] if slot_index < ProcedureData.demand_sequence.size() else ""
	var def = ProcedureData.get_instrument(id)
	name_label.text = def.name_cn if def else str(slot_index + 1)


func can_accept(inst: Instrument) -> bool:
	return inst.def != null and inst.def.slot_index == slot_index


func set_feedback(correct: bool) -> void:
	_tint(COLOR_OK if correct else COLOR_BAD)
	if not correct:
		await get_tree().create_timer(0.3).timeout
		_tint(TAG_COLOR)


func clear_feedback() -> void:
	_tint(TAG_COLOR)


func _tint(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	tag.material_override = mat
