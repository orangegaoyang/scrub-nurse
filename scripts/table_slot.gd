class_name TableSlot
extends Area3D
## A slot on the instrument table. Accepts the instrument whose slot_index matches.

@export var slot_index: int = 0
var occupied: bool = false
var current_instrument: Instrument = null

@onready var outline: MeshInstance3D = $Outline
@onready var index_label: Label3D = $IndexLabel


func _ready() -> void:
	index_label.text = str(slot_index + 1)


func can_accept(inst: Instrument) -> bool:
	return inst.def != null and inst.def.slot_index == slot_index


func set_feedback(correct: bool) -> void:
	var mat := StandardMaterial3D.new()
	if correct:
		mat.albedo_color = Color(0.2, 0.9, 0.3, 0.6)
		outline.material_override = mat
	else:
		mat.albedo_color = Color(0.9, 0.2, 0.2, 0.6)
		outline.material_override = mat
		await get_tree().create_timer(0.3).timeout
		outline.material_override = null
