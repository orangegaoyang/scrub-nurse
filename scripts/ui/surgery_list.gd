class_name SurgeryList
extends Control
## Surgery list rendered into the intro schedule board's SubViewport. The paper
## background and list container live in surgery_list.tscn; this script only
## instantiates one surgery_row.tscn per entry in data/surgery.json. The
## schedule board maps 3D clicks into viewport pixels and asks this list which
## row (if any) they landed on.

const SURGERY_JSON := "res://data/surgery.json"
const ROW_SCENE := preload("res://scenes/ui/surgery_row.tscn")

@onready var list: VBoxContainer = $List

var _entries: Array = []
var _hover_index: int = -1


func _ready() -> void:
	_entries = _load_surgeries()
	for entry in _entries:
		var row: SurgeryRow = ROW_SCENE.instantiate()
		list.add_child(row)
		row.setup(entry["procedure"], entry["type"], entry["surgeon"], entry["level"])


func row_at(point: Vector2) -> int:
	## Index of the row whose rect contains `point` (viewport-local pixels),
	## or -1 when the click landed on the paper but outside every row.
	for i in range(list.get_child_count()):
		var row: Control = list.get_child(i)
		if row.get_global_rect().has_point(point):
			return i
	return -1


func set_hover_row(index: int) -> void:
	## Move the hover pop to the row under the cursor (-1 clears it).
	if index == _hover_index:
		return
	if _hover_index >= 0 and _hover_index < list.get_child_count():
		(list.get_child(_hover_index) as SurgeryRow).set_hovered(false)
	_hover_index = index
	if index >= 0 and index < list.get_child_count():
		(list.get_child(index) as SurgeryRow).set_hovered(true)


func get_entry(index: int) -> Dictionary:
	if index < 0 or index >= _entries.size():
		return {}
	return _entries[index]


func highlight_row(index: int) -> void:
	## Quick press-pop on the clicked row so the choice reads before the fade.
	if index < 0 or index >= list.get_child_count():
		return
	var row: Control = list.get_child(index)
	row.pivot_offset = row.size * 0.5
	var tw := row.create_tween()
	tw.tween_property(row, "scale", Vector2(1.045, 1.045), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _load_surgeries() -> Array:
	var result: Array = []
	if not FileAccess.file_exists(SURGERY_JSON):
		push_error("SurgeryList: surgery.json not found at %s" % SURGERY_JSON)
		return result
	var file := FileAccess.open(SURGERY_JSON, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("SurgeryList: failed to parse surgery.json")
		return result
	for entry in parsed:
		result.append({
			"procedure": entry.get("procedure", ""),
			"type": entry.get("type", ""),
			"surgeon": entry.get("surgeon", ""),
			"level": int(entry.get("scrub nurse level", 1)),
		})
	return result
