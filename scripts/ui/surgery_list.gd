class_name SurgeryList
extends Control
## Surgery list rendered into the intro schedule board's SubViewport. The paper
## background and list container live in surgery_list.tscn; this script only
## instantiates one surgery_row.tscn per entry in data/surgery.json.

const SURGERY_JSON := "res://data/surgery.json"
const ROW_SCENE := preload("res://scenes/ui/surgery_row.tscn")

@onready var list: VBoxContainer = $List


func _ready() -> void:
	for entry in _load_surgeries():
		var row: SurgeryRow = ROW_SCENE.instantiate()
		list.add_child(row)
		row.setup(entry["procedure"], entry["type"], entry["surgeon"], entry["level"])


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
