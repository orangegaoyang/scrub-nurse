extends Node3D
## Intro:
## Day 1: physics-drop badge → click to pick up (lifts toward camera), mouse
##   follows on the table plane, click to drop → snap into slot if horizontally
##   close, else free-fall back onto the table → wait 1s → drop schedule
##   → click schedule → proceed to corridor.
## Replay (same session): badge already in slot, wait 1s, drop schedule.
##
## Props own their own interaction:
##   - BadgeProp    → scripts/intro_badge.gd    (pick-up / drag / snap)
##   - ScheduleProp → scripts/intro_schedule.gd (cell grid + proceed signal)
## This script drives the scene flow and the shared table-contact freeze.

const SCHEDULE_DELAY := 1.0
const REST_Y := 1.3 # table top (1.2) + half collision-box height (0.1)
const THROW_TIMEOUT := 3.0

# Persists across scene reloads within one process: skip the badge drop on
# replays (badge stays in slot).
static var _intro_seen_once := false

@onready var camera: Camera3D = $Camera3D
@onready var badge: IntroBadge = $BadgeProp
@onready var schedule: IntroSchedule = $ScheduleProp
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice


func _ready() -> void:
	#camera.look_at(Vector3(0.0, 1.45, 0.0))
	badge.visible = false
	slot.visible = false
	badge.setup(camera, slot)
	schedule.proceed.connect(_on_schedule_proceed)
	await Transition.fade_in()
	if _intro_seen_once:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.visible = true
	badge.freeze = false
	_intro_seen_once = true
	_voice("intro_badge")
	badge.start_hint()
	await badge.placed
	await _wait(SCHEDULE_DELAY)
	_throw_schedule()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then throw schedule.
	badge.place_in_slot()
	await _wait(1.0)
	_throw_schedule()


func _throw_schedule() -> void:
	schedule.reveal()
	_voice("intro_schedule")


# ---------------- Table contact ----------------

func _on_table_area_3d_body_entered(body: Node3D) -> void:
	if body == badge:
		badge.freeze = true
	if body == schedule:
		schedule.freeze = true


# ---------------- Schedule transition ----------------

func _on_schedule_proceed() -> void:
	await Transition.fade_out()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/corridor.tscn")


# ---------------- Helpers ----------------
func _settle_and_freeze(body: RigidBody3D) -> void:
	var elapsed := 0.0
	while not body.sleeping and elapsed < THROW_TIMEOUT:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.rotation = Vector3.ZERO


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

