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
	var slot_index: int
	var uses: int  # total uses, derived from demand-sequence occurrences
	var count: int  # how many instances of this instrument are laid out
	var discard: bool  # the surgeon throws it away himself after use (gauze)

	func _init(p_id: String, p_name_cn: String,p_name_en: String, p_category: String,
			   p_purpose: String, p_slot_index: int, p_uses: int,
			   p_count: int = 1, p_discard: bool = false) -> void:
		id = p_id
		name_cn = p_name_cn
		name_en = p_name_en
		category = p_category
		purpose = p_purpose
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
# Shared instrument catalog: static metadata (name/category/purpose) identical
# across procedures, stored once here instead of duplicated per procedure file.
const INSTRUMENTS_PATH := "res://data/instruments.json"

# id -> InstrumentDef
var instruments: Dictionary = {}
# id -> raw catalog entry {id,name_cn,name_en,category,purpose} from instruments.json
var _catalog: Dictionary = {}
# Unique instrument ids ordered by slot_index (prep layout order).
var instrument_order: Array[String] = []
# Demand sequence: ordered list of instrument ids, reuse allowed.
var demand_sequence: Array[String] = []
# Procedure title (shown on the intro board / sticker)
var procedure_id: String = ""
# Feature flags: which mechanics this procedure teaches.
var _neutral_zone: bool = false
var _back_table: bool = false
var _surgery_free_mayo: bool = false
var _bpm: float = 96.0  # 术中节奏速度:难度即速度


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


func tempo() -> float:
	return _bpm


func _load_catalog() -> void:
	## Load the static instrument metadata that every procedure shares.
	_catalog.clear()
	if not FileAccess.file_exists(INSTRUMENTS_PATH):
		push_error("ProcedureData: %s not found" % INSTRUMENTS_PATH)
		return
	var file := FileAccess.open(INSTRUMENTS_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ProcedureData: failed to parse %s" % INSTRUMENTS_PATH)
		return
	for entry in parsed:
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			continue
		_catalog[id] = entry


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
	_load_catalog()

	var arr: Array = parsed.get("instruments", [])
	procedure_id = parsed.get("procedure_id", "")
	_neutral_zone = bool(parsed.get("neutral_zone", false))
	_back_table = bool(parsed.get("back_table", false))
	_surgery_free_mayo = bool(parsed.get("surgery_free_mayo", false))
	_bpm = float(parsed.get("bpm", 96.0))
	instruments.clear()
	instrument_order.clear()
	demand_sequence.clear()

	# First pass: collect this procedure's ids + their raw slot_index (needed to
	# order the legacy no-sequence fallback before defs exist).
	var raw_order: Array[String] = []
	var entry_slots: Dictionary = {}
	for entry in arr:
		var id: String = str(entry["id"])
		raw_order.append(id)
		entry_slots[id] = int(entry.get("slot_index", 0))

	# Demand sequence: explicit list when present, else one appearance per
	# instrument in slot order (legacy behaviour).
	var seq: Array = parsed.get("sequence", [])
	if seq.size() > 0:
		for id in seq:
			demand_sequence.append(id)
	else:
		var slot_order: Array[String] = raw_order.duplicate()
		slot_order.sort_custom(func(a, b): return entry_slots[a] < entry_slots[b])
		demand_sequence = slot_order

	# Total `uses` per instrument = how many times it appears in the demand
	# sequence, so the per-procedure uses value need not be authored.
	var use_count: Dictionary = {}
	for id in demand_sequence:
		use_count[id] = int(use_count.get(id, 0)) + 1

	# Build defs. Static metadata (name/category/purpose) comes from the shared
	# catalog; layout (slot_index/count/discard) is per-procedure.
	for entry in arr:
		var id: String = str(entry["id"])
		var cat: Dictionary = _catalog.get(id, {})
		if cat.is_empty():
			push_warning("ProcedureData: %s has no entry in %s" % [id, INSTRUMENTS_PATH])
		var def := InstrumentDef.new(
			id,
			str(cat.get("name_cn", "")),
			str(cat.get("name_en", "")),
			str(cat.get("category", "")),
			str(cat.get("purpose", "")),
			int(entry.get("slot_index", 0)),
			int(use_count.get(id, 0)),
			int(entry.get("count", 1)),
			bool(cat.get("discard", false))
		)
		instruments[id] = def
		instrument_order.append(id)

	instrument_order.sort_custom(func(a, b): return instruments[a].slot_index < instruments[b].slot_index)


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
