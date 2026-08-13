class_name SurgeryListItem
extends Node3D
## One row of the intro surgery list, built from data/surgery.json.
## Columns (item-local, board is 0.42 wide with its origin at the centre):
##   [type icon + procedure name]  [person icon + surgeon name]  [Level badge].
## Populated via setup(); emits `clicked` when the row is picked.

signal clicked

const ICON_DIR := "res://assets/2D/intro/surgery_icon"
const FONT_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const SHADER_PATH := "res://shaders/rounded_rect.gdshader"

# blue-gray ink used for all text and the generated person icon
const INK := Color(0.35, 0.42, 0.52)

const FONT_SIZE := 26
const PIXEL_SIZE := 0.0006
# max width of the procedure text before it wraps to a second line
const PROCEDURE_WRAP := 0.115

# type string -> icon file basename (in ICON_DIR, without extension)
const TYPE_ICON := {
	"General Surgery": "General",
	"Orthopedics": "Orthopedics",
	"Obstetrics": "Obstetrics",
	"Neurosurgery": "Neurosurgery",
	"Cardiac": "Cardiac",
	"Cardiac Surgery": "Cardiac",
}

# scrub nurse level -> { label text, background colour }
const LEVEL_STYLE := {
	1: {"label": "Level I",   "bg": Color(0.70, 0.87, 0.66)},   # light green
	2: {"label": "Level II",  "bg": Color(0.95, 0.90, 0.60)},   # light yellow
	3: {"label": "Level III", "bg": Color(0.82, 0.76, 0.93)},   # light purple
}

const BADGE_SIZE := Vector2(0.11, 0.05)

@onready var type_icon: MeshInstance3D = $TypeIcon
@onready var procedure_label: Label3D = $ProcedureLabel
@onready var surgeon_icon: MeshInstance3D = $SurgeonIcon
@onready var surgeon_label: Label3D = $SurgeonLabel
@onready var level_badge: MeshInstance3D = $LevelBadge
@onready var level_label: Label3D = $LevelLabel


func _ready() -> void:
	var font := load(FONT_PATH) as Font
	_style_label(procedure_label, font, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label(surgeon_label, font, HORIZONTAL_ALIGNMENT_LEFT)
	_style_label(level_label, font, HORIZONTAL_ALIGNMENT_CENTER)
	procedure_label.width = PROCEDURE_WRAP
	procedure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_label.width = BADGE_SIZE.x
	surgeon_icon.material_override = _make_icon_material(_make_person_icon())
	$ClickArea.input_event.connect(_on_input_event)


func setup(procedure: String, type: String, surgeon: String, level: int) -> void:
	procedure_label.text = procedure
	surgeon_label.text = surgeon
	type_icon.material_override = _make_icon_material(_load_type_icon(type))
	var style: Dictionary = LEVEL_STYLE.get(level, LEVEL_STYLE[1])
	level_label.text = style["label"]
	level_badge.material_override = _make_badge_material(style["bg"])


# ---------------- Build helpers ----------------

func _style_label(lbl: Label3D, font: Font, align: int) -> void:
	lbl.font = font
	lbl.font_size = FONT_SIZE
	lbl.pixel_size = PIXEL_SIZE
	lbl.modulate = INK
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.no_depth_test = true
	lbl.render_priority = 3
	lbl.horizontal_alignment = align


func _make_icon_material(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.render_priority = 2
	return mat


func _make_badge_material(bg: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("color", bg)
	mat.set_shader_parameter("alpha", 1.0)
	mat.set_shader_parameter("size", BADGE_SIZE)
	mat.set_shader_parameter("corner_radius", BADGE_SIZE.y * 0.5)
	mat.render_priority = 2
	return mat


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


# ---------------- Interaction ----------------

func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
