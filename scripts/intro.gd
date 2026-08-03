extends Node3D
## Intro: a two-shot cinematic over the unchanged bg.png backdrop.
## Shot 1 — a hand reaches in with the intern's ID badge; voice welcomes
##   them; the badge flies to the top-left and becomes the badge UI.
## Shot 2 — the hand delivers today's surgery schedule; voice explains;
##   the easiest case blinks until the player clicks it to start the day.
## All props are placeholder boxes until real art is provided.

const HAND_OFF := Vector3(1.3, 1.25, 0.35)
const HAND_HOLD := Vector3(0.25, 1.32, 0.05)
const HAND_PLACE := Vector3(0.0, 1.28, 0.0)
const SLIDE_TIME := 0.45

# Today's surgery schedule. `easy` marks the playable case (first day, pick an
# easy one). Placeholder rows; swap for real content / art later.
const SCHEDULE := [
	{time = "08:00", name = "门诊小手术", doctor = "Dr. 李", level = "实习", easy = true},
	{time = "09:30", name = "阑尾切除术", doctor = "Dr. 陈", level = "初级", easy = false},
	{time = "11:00", name = "胆囊切除术", doctor = "Dr. 王", level = "中级", easy = false},
	{time = "14:00", name = "心脏搭桥", doctor = "Dr. 赵", level = "高级", easy = false},
]

@onready var camera: Camera3D = $Camera3D
@onready var hand: Node3D = $Hand
@onready var held_anchor: Node3D = $Hand/HeldAnchor
@onready var badge_prop: MeshInstance3D = $BadgeProp
@onready var schedule_prop: MeshInstance3D = $ScheduleProp
@onready var badge_ui: Control = $UI/BadgeUI
@onready var schedule_ui: Control = $UI/ScheduleUI
@onready var rows_box: VBoxContainer = $UI/ScheduleUI/Panel/Margin/VBox/Rows
@onready var voice: AudioStreamPlayer = $Voice

var _proceeding: bool = false


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	hand.position = HAND_OFF
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
	badge_prop.reparent(held_anchor)
	badge_prop.transform = Transform3D.IDENTITY
	_slide_to(HAND_HOLD)
	await _wait(SLIDE_TIME + 0.2)
	_voice("intro_badge")
	await _wait(2.4)
	# Badge detaches, flies to the top-left, and becomes the badge UI.
	badge_prop.reparent(self)
	badge_prop.global_position = held_anchor.global_position
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(badge_prop, "global_position", _top_left_world(), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_property(badge_prop, "scale", Vector3.ZERO, 0.7).set_ease(Tween.EASE_IN)
	fly.tween_property(badge_ui, "modulate:a", 1.0, 0.5).set_delay(0.35)
	await fly.finished
	badge_prop.visible = false
	_slide_to(HAND_OFF)
	await _wait(SLIDE_TIME)


# ---------------- Shot 2: schedule ----------------

func _shot2() -> void:
	schedule_prop.visible = true
	schedule_prop.reparent(held_anchor)
	schedule_prop.transform = Transform3D.IDENTITY
	_slide_to(HAND_HOLD)
	await _wait(SLIDE_TIME + 0.2)
	_voice("intro_schedule")
	await _wait(2.6)
	# Place the schedule on the table, retract the hand.
	schedule_prop.reparent(self)
	schedule_prop.global_position = held_anchor.global_position
	var place := create_tween()
	place.tween_property(schedule_prop, "global_position", HAND_PLACE + Vector3(0, 0.03, 0), 0.4) \
		.set_ease(Tween.EASE_OUT)
	await place.finished
	_slide_to(HAND_OFF)
	await _wait(0.3)
	# Reveal the interactive schedule and blink the easy case.
	var reveal := create_tween()
	reveal.tween_property(schedule_ui, "modulate:a", 1.0, 0.4)
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


func _slide_to(pos: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(hand, "position", pos, SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
