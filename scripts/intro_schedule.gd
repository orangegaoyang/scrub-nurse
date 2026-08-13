class_name IntroSchedule
extends RigidBody3D
## The surgery list board in the intro scene. Builds one list item per entry in
## data/surgery.json (type icon + procedure, person icon + surgeon, Level
## badge). Call reveal() to drop it onto the table; emits `proceed` when the
## player clicks any row — the intro scene owns the actual transition to the
## corridor.

signal proceed

const SURGERY_JSON := "res://data/surgery.json"
const ITEM_SCENE := preload("res://scenes/surgery_list_item.tscn")
const ROW_SPACING := 0.06
const ROW_Z0 := -0.01
const VOICE_KEY := "intro_schedule"

@onready var mesh: MeshInstance3D = $Mesh

var _proceeding: bool = false
var _voice: AudioStreamPlayer


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	visible = false
	_build_list()


func setup(voice: AudioStreamPlayer) -> void:
	_voice = voice


func reveal() -> void:
	# Drop onto the table; it comes to rest on the table's StaticBody3D.
	visible = true
	freeze = false
	# Voice line plays on every reveal (first loop and replay).
	Util.play_voice(_voice, VOICE_KEY)


# ---------------- List ----------------

func _build_list() -> void:
	var surgeries := _load_surgeries()
	for i in surgeries.size():
		var item: SurgeryListItem = ITEM_SCENE.instantiate()
		# Parent under the board Mesh so items follow any rotation applied to
		# the paper in the editor (they are laid on the paper, not beside it).
		mesh.add_child(item)
		item.position = Vector3(0, 0, ROW_Z0 + i * ROW_SPACING)
		item.setup(
			surgeries[i]["procedure"],
			surgeries[i]["type"],
			surgeries[i]["surgeon"],
			surgeries[i]["level"])
		item.clicked.connect(_on_item_clicked)


func _load_surgeries() -> Array:
	var list: Array = []
	if not FileAccess.file_exists(SURGERY_JSON):
		push_error("IntroSchedule: surgery.json not found at %s" % SURGERY_JSON)
		return list
	var file := FileAccess.open(SURGERY_JSON, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("IntroSchedule: failed to parse surgery.json")
		return list
	for entry in parsed:
		list.append({
			"procedure": entry.get("procedure", ""),
			"type": entry.get("type", ""),
			"surgeon": entry.get("surgeon", ""),
			"level": int(entry.get("scrub nurse level", 1)),
		})
	return list


func _on_item_clicked() -> void:
	if _proceeding:
		return
	_proceeding = true
	proceed.emit()
