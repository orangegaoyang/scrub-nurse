class_name TableSlot
extends Area3D
## A slot on the instrument table. Accepts the instrument whose slot_index matches.
## Shows the name of the instrument that belongs here; feedback flashes the label.

@export var slot_index: int = 0
var occupied: bool = false
var current_instrument: Instrument = null

const LABEL_COLOR := Color(0.9, 0.9, 0.9, 1)
const COLOR_OK := Color(0.3, 0.95, 0.4, 1)
const COLOR_BAD := Color(0.95, 0.25, 0.25, 1)

@onready var index_label: Label3D = $IndexLabel


func _ready() -> void:
	# Label = the name of the instrument that belongs in this slot.
	var id = ProcedureData.demand_sequence[slot_index] if slot_index < ProcedureData.demand_sequence.size() else ""
	var def = ProcedureData.get_instrument(id)
	index_label.text = def.name_cn if def else str(slot_index + 1)
	index_label.modulate = LABEL_COLOR


func can_accept(inst: Instrument) -> bool:
	return inst.def != null and inst.def.slot_index == slot_index


func set_feedback(correct: bool) -> void:
	index_label.modulate = COLOR_OK if correct else COLOR_BAD
	if not correct:
		await get_tree().create_timer(0.3).timeout
		index_label.modulate = LABEL_COLOR


func clear_feedback() -> void:
	index_label.modulate = LABEL_COLOR
