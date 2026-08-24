extends Node
## ProcedureData autoload: instrument definitions + demand sequence + per-
## procedure feature flags, loaded for the surgery picked on the intro
## schedule. Three procedures implement the progression:
##   S1 Appendectomy   — Mayo only, slot returns, doctor hands back directly.
##   S2 Knee Replacement — + neutral zone, all instruments reusable, free mayo.
##   S3 Craniotomy      — + back table, full return judgment + tidy-up.

class InstrumentDef:
	var id: String
	var name_cn: String
	var name_en: String
	var category: String
	var purpose: String
	var color: Color
	var slot_index: int
	var uses: int
	var count: int  # how many instances of this instrument are laid out
	var discard: bool  # the surgeon throws it away himself after use (gauze)

	func _init(p_id: String, p_name_cn: String, p_name_en: String,
			   p_category: String, p_purpose: String, p_color: Color,
			   p_slot_index: int, p_uses: int, p_count: int = 1,
			   p_discard: bool = false) -> void:
		id = p_id
		name_cn = p_name_cn
		name_en = p_name_en
		category = p_category
		purpose = p_purpose
		color = p_color
		slot_index = p_slot_index
		uses = p_uses
		count = p_count
		discard = p_discard


# Schedule-row procedure name -> data file.
const FILE_MAP := {
	"Appendectomy": "res://data/procedure_1.json",
	"Total Knee Replacement": "res://data/procedure_2.json",
	"Craniotomy": "res://data/procedure_3.json",
}
const DEFAULT_FILE := "res://data/procedure_1.json"

# id -> InstrumentDef
var instruments: Dictionary = {}
# Unique instrument ids ordered by slot_index (prep layout order).
var instrument_order: Array[String] = []
# Demand sequence: ordered list of instrument ids, reuse allowed.
var demand_sequence: Array[String] = []
# Procedure title (shown on the intro board / sticker)
var procedure_id: String = ""
var procedure_name: String = ""
var procedure_name_en: String = ""
# Feature flags: which mechanics this procedure teaches.
var _neutral_zone: bool = false
var _back_table: bool = false
var _surgery_free_mayo: bool = false


func reload_for_selected() -> void:
	## Load the procedure for the surgery picked on the intro schedule.
	var proc_name: String = ""
	if not GameState.selected_surgery.is_empty() and GameState.selected_surgery.has("procedure"):
		proc_name = GameState.selected_surgery["procedure"]
	var path: String = FILE_MAP.get(proc_name, DEFAULT_FILE)
	_load_procedure(path)


func has_neutral_zone() -> bool:
	return _neutral_zone


func has_back_table() -> bool:
	return _back_table


func surgery_free_mayo() -> bool:
	return _surgery_free_mayo


func _load_procedure(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("ProcedureData: %s not found" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ProcedureData: failed to parse %s" % path)
		return

	var arr: Array = parsed.get("instruments", [])
	procedure_id = parsed.get("procedure_id", "")
	procedure_name = parsed.get("procedure_name", "")
	procedure_name_en = parsed.get("procedure_name_en", "")
	_neutral_zone = bool(parsed.get("neutral_zone", false))
	_back_table = bool(parsed.get("back_table", false))
	_surgery_free_mayo = bool(parsed.get("surgery_free_mayo", false))
	instruments.clear()
	instrument_order.clear()
	demand_sequence.clear()
	for entry in arr:
		var c: Color = Color(entry["color_r"], entry["color_g"], entry["color_b"])
		var def := InstrumentDef.new(
			entry["id"], entry["name_cn"], entry["name_en"],
			entry["category"], entry["purpose"], c,
			int(entry["slot_index"]), int(entry.get("uses", 1)),
			int(entry.get("count", 1)), bool(entry.get("discard", false))
		)
		instruments[entry["id"]] = def
		instrument_order.append(entry["id"])

	# Prep layout order = slot_index order.
	instrument_order.sort_custom(func(a, b): return instruments[a].slot_index < instruments[b].slot_index)

	# Demand sequence: explicit list when present, else one appearance each
	# in slot order (legacy behaviour).
	var seq: Array = parsed.get("sequence", [])
	if seq.size() > 0:
		for id in seq:
			demand_sequence.append(id)
	else:
		demand_sequence = instrument_order.duplicate()


func get_instrument(id: String) -> InstrumentDef:
	return instruments.get(id)


func get_demand_at(index: int) -> String:
	if index < 0 or index >= demand_sequence.size():
		return ""
	return demand_sequence[index]


func demand_count() -> int:
	return demand_sequence.size()


func total_instances() -> int:
	## Total laid-out instrument instances (unique defs × their count). The
	## tidy/result totals must use this, not instrument_order.size(), because
	## multi-instance items like gauze exist several times.
	var n: int = 0
	for id in instrument_order:
		n += instruments[id].count
	return n


func usage_at(index: int) -> Dictionary:
	## {id, usage, total}: the instrument demanded at `index` and whether this
	## is its 1st/2nd/... use out of its total.
	var id: String = get_demand_at(index)
	if id.is_empty():
		return {}
	var total: int = instruments[id].uses
	var usage: int = 0
	for i in range(0, min(index + 1, demand_sequence.size())):
		if demand_sequence[i] == id:
			usage += 1
	return {"id": id, "usage": usage, "total": total}


func remaining_uses(id: String, from_index: int) -> int:
	## How many more times `id` appears in the sequence from `from_index` on.
	var n: int = 0
	for i in range(from_index, demand_sequence.size()):
		if demand_sequence[i] == id:
			n += 1
	return n
