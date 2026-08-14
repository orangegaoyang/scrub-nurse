class_name SurgeryRow
extends HBoxContainer
## One surgery row. Layout/styling live in surgery_row.tscn; this script only
## fills the dynamic content (text, type icon, badge colour) and generates the
## placeholder person icon.

const ICON_DIR := "res://assets/2D/intro/surgery_icon"

const TYPE_ICON := {
	"General Surgery": "General",
	"Orthopedics": "Orthopedics",
	"Obstetrics": "Obstetrics",
	"Neurosurgery": "Neurosurgery",
	"Cardiac": "Cardiac",
	"Cardiac Surgery": "Cardiac",
}

const LEVEL_STYLE := {
	1: {"label": "Level I",   "bg": Color("#d5d2ad")},   # light green
	2: {"label": "Level II",  "bg": Color("#ecd3a4")},   # light yellow
	3: {"label": "Level III", "bg": Color("#dac9cf")},   # light purple
}

const INK := Color(0.35, 0.42, 0.52)

@onready var type_icon: TextureRect = $Procedure/TypeIcon
@onready var procedure_label: Label = $Procedure/ProcedureLabel
@onready var type_label: Label = $TypeLabel
@onready var surgeon_icon: TextureRect = $Surgeon/SurgeonIcon
@onready var surgeon_label: Label = $Surgeon/SurgeonLabel
@onready var level_badge: PanelContainer = $LevelBadge
@onready var level_label: Label = $LevelBadge/LevelLabel


func setup(procedure: String, type: String, surgeon: String, level: int) -> void:
	procedure_label.text = procedure
	type_label.text = type
	surgeon_label.text = surgeon
	type_icon.texture = _load_type_icon(type)
	var style: Dictionary = LEVEL_STYLE.get(level, LEVEL_STYLE[1])
	level_label.text = style["label"]
	var sb: StyleBoxFlat = level_badge.get_theme_stylebox("panel").duplicate()
	sb.bg_color = style["bg"]
	level_badge.add_theme_stylebox_override("panel", sb)


# ---------------- Assets ----------------

func _load_type_icon(type: String) -> Texture2D:
	var base: String = TYPE_ICON.get(type, "")
	if base.is_empty():
		base = _guess_type_icon(type)
	if base.is_empty():
		return null
	return load("%s/%s.PNG" % [ICON_DIR, base]) as Texture2D


func _guess_type_icon(type: String) -> String:
	for icon in ["Cardiac", "General", "Neurosurgery", "Obstetrics", "Orthopedics"]:
		if type.contains(icon):
			return icon
	return ""
