extends Node3D
## Intro / title page (3D, mirrors the main scene layout). Start button loads
## the surgery scene. The board shows the procedure name, the sticker a note.

@onready var start_btn: TextureButton = $UI/StartBtn
@onready var camera: Camera3D = $Camera3D
@onready var board_title: Label3D = $SurgeryBoard/Title
@onready var sticker_note: Label3D = $Sticker/Note


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	board_title.text = ProcedureData.procedure_name
	sticker_note.text = ProcedureData.procedure_name_en


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
