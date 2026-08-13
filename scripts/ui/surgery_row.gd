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

@onready var type_icon: TextureRect = $TypeIcon
@onready var procedure_label: Label = $NameBox/ProcedureLabel
@onready var type_label: Label = $NameBox/TypeLabel
@onready var surgeon_icon: TextureRect = $SurgeonIcon
@onready var surgeon_label: Label = $SurgeonLabel
@onready var level_badge: PanelContainer = $LevelBadge
@onready var level_label: Label = $LevelBadge/LevelLabel


func _ready() -> void:
	surgeon_icon.texture = _make_person_icon()


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


func _make_person_icon() -> ImageTexture:
	# Simple person silhouette (head circle + shoulders dome), tinted with INK.
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var head_c := Vector2(s * 0.5, s * 0.31)
	var head_r := s * 0.16
	var shoulder_c := Vector2(s * 0.5, s * 0.48)
	var rx := s * 0.34
	var ry := s * 0.30
	for y in range(s):
		for x in range(s):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(head_c) <= head_r:
				img.set_pixel(x, y, INK)
			elif p.y >= shoulder_c.y:
				var e := pow((p.x - shoulder_c.x) / rx, 2.0) + pow((p.y - shoulder_c.y) / ry, 2.0)
				if e <= 1.0:
					img.set_pixel(x, y, INK)
	return ImageTexture.create_from_image(img)
