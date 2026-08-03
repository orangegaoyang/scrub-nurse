extends Node3D
## Intro: badge and schedule drift gently from above onto the table center,
## then UI fades in. No hand model.

const DROP_FROM := Vector3(0.0, 2.5, -0.6)
const REST_POS := Vector3(0.0, 1.21, 0.0)
const DROP_TIME := 1.4
const FLY_TIME := 1.4

# Today's surgery schedule. `easy` marks the playable case (first day, pick an
# easy one). Placeholder rows; swap for real content / art later.
const SCHEDULE := [
	{time = "08:00", name = "门诊小手术", doctor = "Dr. 李", level = "实习", easy = true},
	{time = "09:30", name = "阑尾切除术", doctor = "Dr. 陈", level = "初级", easy = false},
	{time = "11:00", name = "胆囊切除术", doctor = "Dr. 王", level = "中级", easy = false},
	{time = "14:00", name = "心脏搭桥", doctor = "Dr. 赵", level = "高级", easy = false},
]

@onready var camera: Camera3D = $Camera3D
@onready var badge_prop: MeshInstance3D = $BadgeProp
@onready var schedule_prop: MeshInstance3D = $ScheduleProp
@onready var badge_ui: Control = $UI/BadgeUI
@onready var schedule_ui: Control = $UI/ScheduleUI
@onready var rows_box: VBoxContainer = $UI/ScheduleUI/Panel/Margin/VBox/Rows
@onready var voice: AudioStreamPlayer = $Voice

var _proceeding: bool = false


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	badge_prop.visible = false
	schedule_prop.visible = false
	badge_ui.modulate.a = 0.0
	schedule_ui.modulate.a = 0.0
	_build_schedule_rows()
	await Transition.fade_in()
	await _shot1()
	await _shot2()


# ---------------- Shot 1: badge ----------------

func _shot1() -> void:
	badge_prop.visible = true
	badge_prop.global_position = DROP_FROM
	badge_prop.scale = Vector3.ONE
	var drop := create_tween().set_parallel(true)
	drop.tween_property(badge_prop, "global_position:y", REST_POS.y, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(badge_prop, "global_position:z", REST_POS.z, DROP_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	await drop.finished
	_voice("intro_badge")
	await _wait(2.4)
	# 飘到屏幕左上角化作 BadgeUI
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(badge_prop, "global_position", _top_left_world(), FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(badge_prop, "scale", Vector3.ZERO, FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_property(badge_ui, "modulate:a", 1.0, 0.6).set_delay(0.5)
	await fly.finished
	badge_prop.visible = false


# ---------------- Shot 2: schedule ----------------

func _shot2() -> void:
	schedule_prop.visible = true
	schedule_prop.global_position = DROP_FROM
	var drop := create_tween().set_parallel(true)
	drop.tween_property(schedule_prop, "global_position:y", REST_POS.y, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(schedule_prop, "global_position:z", REST_POS.z, DROP_TIME) \
		.set_trans(Tween.TRANS_LINEAR)
	await drop.finished
	_voice("intro_schedule")
	await _wait(2.6)
	var reveal := create_tween()
	reveal.tween_property(schedule_ui, "modulate:a", 1.0, 0.5)
	await reveal.finished
	_start_blink()


func _start_blink() -> void:
	var row := rows_box.get_node("EasyRow")
	var tw := create_tween().set_loops()
	tw.tween_property(row, "modulate:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(row, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_easy_clicked() -> void:
	if _proceeding:
		return
	_proceeding = true
	await Transition.fade_out()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/corridor.tscn")


# ---------------- helpers ----------------

func _build_schedule_rows() -> void:
	for entry in SCHEDULE:
		var text := "%s     %s     %s     %s" % [entry.time, entry.name, entry.doctor, entry.level]
		if entry.easy:
			var btn := Button.new()
			btn.text = text
			btn.name = "EasyRow"
			btn.add_theme_font_size_override("font_size", 19)
			btn.pressed.connect(_on_easy_clicked)
			rows_box.add_child(btn)
		else:
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", 19)
			lbl.modulate.a = 0.5
			rows_box.add_child(lbl)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _voice(key: String) -> void:
	var path := "res://assets/audio/%s.wav" % key
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		voice.stream = s
		voice.play()


func _top_left_world() -> Vector3:
	# A world point that projects to the upper-left of the screen, on the
	# y=1.45 plane (roughly table height) -- the badge flies toward here.
	var vp := get_viewport().get_visible_rect().size
	var p := Vector2(vp.x * 0.12, vp.y * 0.30)
	var from := camera.project_ray_origin(p)
	var dir := camera.project_ray_normal(p)
	var t := (1.45 - from.y) / dir.y
	return from + dir * t
