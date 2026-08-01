extends Node3D
## Intro / title page (3D, mirrors the main scene layout). Start button loads
## the surgery scene. The board shows the procedure name, the sticker a note.
## Subtle idle motion: slow background drift, a unified Y bob of the MayoStand,
## and a gentle sunlight energy breathing. Featured elements cascade in.

@onready var start_btn: TextureButton = $UI/StartBtn
@onready var camera: Camera3D = $Camera3D
@onready var backdrop: Sprite3D = $Camera3D/Backdrop
@onready var light: DirectionalLight3D = $DirectionalLight3D
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
	# Featured elements start hidden for the staggered entrance.
	board.scale = Vector3.ZERO
	sticker.scale = Vector3.ZERO
	start_btn.modulate.a = 0.0
	_start_bg_drift()
	_start_light_breath()
	await Transition.fade_in()
	_entrance()


func _start_bg_drift() -> void:
	# 12s loop: 0 -> +3 -> 0 -> -3 -> 0 px (very slow background sway).
	var tw := create_tween().set_loops()
	tw.tween_property(backdrop, "offset:x", 3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", -3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "offset:x", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_light_breath() -> void:
	# Sunlight slowly breathing: 0.95 -> 1.05 -> 0.95 over ~9s.
	light.light_energy = 0.95
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.05, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(light, "light_energy", 0.95, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _entrance() -> void:
	# Cascade in: board, sticker, start button — 0.2s apart.
	var b := create_tween()
	b.tween_property(board, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var s := create_tween()
	s.tween_property(sticker, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	var btn := create_tween()
	btn.tween_property(start_btn, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_delay(0.4)


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
