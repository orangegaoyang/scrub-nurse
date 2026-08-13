class_name SurgeryList
extends Control
## 2D surgery list rendered into the intro schedule board's SubViewport.
## Builds the paper background (surgery.png) plus one auto-laid-out row per
## entry in data/surgery.json. Containers (VBox/HBox) do the layout, so there
## are no hard-coded 3D coordinates to maintain.

const SURGERY_JSON := "res://data/surgery.json"
const PAPER_PATH := "res://assets/2D/intro/surgery.png"
const FONT_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const ICON_DIR := "res://assets/2D/intro/surgery_icon"

# blue-gray ink for all text and the generated person icon
const INK := Color(0.35, 0.42, 0.52)

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

# list area margins inside the paper, in viewport pixels
const LIST_LEFT := 60
const LIST_TOP := 170
const LIST_RIGHT := 60
const LIST_BOTTOM := 60

var _font: Font
var _person_icon: ImageTexture


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_person_icon = _make_person_icon()
	_build()


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = load(PAPER_PATH) as Texture2D
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var list := VBoxContainer.new()
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_left = LIST_LEFT
	list.offset_top = LIST_TOP
	list.offset_right = -LIST_RIGHT
	list.offset_bottom = -LIST_BOTTOM
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)

	for entry in _load_surgeries():
		var row := _make_row(entry["procedure"], entry["type"], entry["surgeon"], entry["level"])
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_child(row)


func _make_row(procedure: String, type: String, surgeon: String, level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var icon := TextureRect.new()
	icon.texture = _load_type_icon(type)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	# procedure name + type name stacked (type is the smaller subtitle)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 0)
	var proc := Label.new()
	proc.text = procedure
	proc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proc.custom_minimum_size = Vector2(0, 0)
	_style_label(proc, 40, INK)
	name_box.add_child(proc)
	var type_lbl := Label.new()
	type_lbl.text = type
	_style_label(type_lbl, 26, Color(0.55, 0.62, 0.70))
	name_box.add_child(type_lbl)
	row.add_child(name_box)

	var person := TextureRect.new()
	person.texture = _person_icon
	person.custom_minimum_size = Vector2(40, 40)
	person.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	person.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(person)

	var surgeon_lbl := Label.new()
	surgeon_lbl.text = surgeon
	surgeon_lbl.custom_minimum_size = Vector2(180, 0)
	_style_label(surgeon_lbl, 34, INK)
	surgeon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(surgeon_lbl)

	row.add_child(_make_badge(level))
	return row


func _make_badge(level: int) -> PanelContainer:
	var style: Dictionary = LEVEL_STYLE.get(level, LEVEL_STYLE[1])
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = style["bg"]
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = style["label"]
	_style_label(lbl, 30, INK)
	badge.add_child(lbl)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return badge


func _style_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)


# ---------------- Data + assets ----------------

func _load_surgeries() -> Array:
	var list: Array = []
	if not FileAccess.file_exists(SURGERY_JSON):
		push_error("SurgeryList: surgery.json not found at %s" % SURGERY_JSON)
		return list
	var file := FileAccess.open(SURGERY_JSON, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("SurgeryList: failed to parse surgery.json")
		return list
	for entry in parsed:
		list.append({
			"procedure": entry.get("procedure", ""),
			"type": entry.get("type", ""),
			"surgeon": entry.get("surgeon", ""),
			"level": int(entry.get("scrub nurse level", 1)),
		})
	return list


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
