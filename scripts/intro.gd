extends Node3D
## Intro / title page (3D, mirrors the main scene layout). Start button loads
## the surgery scene. The board shows the procedure name, the sticker a note.
## Subtle idle motion: a very slow background drift + a gentle unified Y bob
## of the MayoStand (with the board/sticker riding it). The camera stays still.

@onready var start_btn: TextureButton = $UI/StartBtn
@onready var camera: Camera3D = $Camera3D
@onready var backdrop: Sprite3D = $Camera3D/Backdrop
@onready var mayo: Node3D = $MayoStand
@onready var board_title: Label3D = $SurgeryBoard/Title
@onready var sticker_note: Label3D = $Sticker/Note
@onready var board: MeshInstance3D = $SurgeryBoard
@onready var sticker: MeshInstance3D = $Sticker

var _t: float = 0.0
var _mayo_y: float
var _board_y: float
var _sticker_y: float


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	board_title.text = ProcedureData.procedure_name
	sticker_note.text = ProcedureData.procedure_name_en
	_mayo_y = mayo.position.y
	_board_y = board.position.y
	_sticker_y = sticker.position.y
	Transition.fade_in()
	_start_bg_drift()


func _start_bg_drift() -> void:
	# 12s loop: 0 -> +3 -> 0 -> -3 -> 0 px (very slow background sway).
	var tw := create_tween().set_loops()
	tw.tween_property(backdrop, "offset:x", 3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", -3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_t += delta
	# Gentle unified Y bob (MayoStand + board + sticker move together so the
	# board/sticker stay glued to the tray). sin = 0 -> +amp -> 0 -> -amp -> 0.
	var bob := sin(_t * TAU / 5.0) * 0.004
	mayo.position.y = _mayo_y + bob
	board.position.y = _board_y + bob
	sticker.position.y = _sticker_y + bob


func _on_start() -> void:
	start_btn.disabled = true
	set_process(false)  # freeze the idle motion during the fade-out
	await Transition.fade_out()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
