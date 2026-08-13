class_name IntroSchedule
extends RigidBody3D
## The surgery list board in the intro scene. Renders a 2D SurgeryList (paper
## background + one row per entry in data/surgery.json) into a SubViewport and
## displays it on the board mesh. Call reveal() to drop it onto the table;
## emits `proceed` when the player clicks the board — the intro scene owns the
## actual transition to the corridor.

signal proceed

const SURGERY_LIST := preload("res://scripts/ui/surgery_list.gd")
const VIEW_SIZE := Vector2i(934, 1010)  # matches surgery.png
const VOICE_KEY := "intro_schedule"

@onready var mesh: MeshInstance3D = $Mesh

var _proceeding: bool = false
var _voice: AudioStreamPlayer


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	visible = false
	input_event.connect(_on_input_event)
	_build_list()


func setup(voice: AudioStreamPlayer) -> void:
	_voice = voice


func reveal() -> void:
	# Drop onto the table; it comes to rest on the table's StaticBody3D.
	visible = true
	freeze = false
	# Voice line plays on every reveal (first loop and replay).
	Util.play_voice(_voice, VOICE_KEY)


func _build_list() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var list: Control = SURGERY_LIST.new()
	list.size = Vector2(VIEW_SIZE)
	viewport.add_child(list)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = viewport.get_texture()
	mat.render_priority = 1
	mesh.material_override = mat


func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceeding = true
		proceed.emit()
