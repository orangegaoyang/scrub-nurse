extends Node3D
## Intro / title page (3D, mirrors the main scene layout). Start button loads
## the surgery scene. The board shows the procedure name, the sticker a note.
## Subtle idle motion: a slow camera drift and a gentle bob on the board/sticker.

@onready var start_btn: TextureButton = $UI/StartBtn
@onready var camera: Camera3D = $Camera3D
@onready var board_title: Label3D = $SurgeryBoard/Title
@onready var sticker_note: Label3D = $Sticker/Note
@onready var board: MeshInstance3D = $SurgeryBoard
@onready var sticker: MeshInstance3D = $Sticker

var _t: float = 0.0
var _cam_base: Vector3
var _board_y: float
var _sticker_y: float


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	board_title.text = ProcedureData.procedure_name
	sticker_note.text = ProcedureData.procedure_name_en
	_cam_base = camera.position
	_board_y = board.position.y
	_sticker_y = sticker.position.y
	Transition.fade_in()


func _process(delta: float) -> void:
	_t += delta
	# Slow breathing drift on the camera (Lissajous, re-aimed at the centre).
	camera.position = _cam_base + Vector3(sin(_t * 0.30) * 0.02, sin(_t * 0.23) * 0.012, 0.0)
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	# Gentle vertical bob on the board and sticker (offset phase so they don't sync).
	board.position.y = _board_y + sin(_t * 0.8) * 0.006
	sticker.position.y = _sticker_y + sin(_t * 1.1 + 1.0) * 0.006


func _on_start() -> void:
	start_btn.disabled = true
	set_process(false)  # freeze the idle motion during the fade-out
	await Transition.fade_out()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
