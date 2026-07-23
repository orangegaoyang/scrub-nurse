extends Node
## ProcedureData autoload: instrument definitions + demand sequence.

class InstrumentDef:
	var id: String
	var name_cn: String
	var name_en: String
	var category: String
	var purpose: String
	var color: Color
	var slot_index: int

	func _init(p_id: String, p_name_cn: String, p_name_en: String,
			   p_category: String, p_purpose: String, p_color: Color,
			   p_slot_index: int) -> void:
		id = p_id
		name_cn = p_name_cn
		name_en = p_name_en
		category = p_category
		purpose = p_purpose
		color = p_color
		slot_index = p_slot_index


# id -> InstrumentDef
var instruments: Dictionary = {}
# demand sequence: ordered list of instrument ids (also the prep slot order)
var demand_sequence: Array[String] = []


func _ready() -> void:
	_load_procedure()


func _load_procedure() -> void:
	var path: String = "res://data/procedure.json"
	if not FileAccess.file_exists(path):
		push_error("ProcedureData: procedure.json not found at %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ProcedureData: failed to parse procedure.json")
		return

	var arr: Array = parsed.get("instruments", [])
	instruments.clear()
	demand_sequence.clear()
	for entry in arr:
		var c: Color = Color(entry["color_r"], entry["color_g"], entry["color_b"])
		var def := InstrumentDef.new(
			entry["id"], entry["name_cn"], entry["name_en"],
			entry["category"], entry["purpose"], c, int(entry["slot_index"])
		)
		instruments[entry["id"]] = def
		demand_sequence.append(entry["id"])

	# Ensure demand order matches slot_index
	demand_sequence.sort_custom(func(a, b): return instruments[a].slot_index < instruments[b].slot_index)


func get_instrument(id: String) -> InstrumentDef:
	return instruments.get(id)


func get_demand_at(index: int) -> String:
	if index < 0 or index >= demand_sequence.size():
		return ""
	return demand_sequence[index]
