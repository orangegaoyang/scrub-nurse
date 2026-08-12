extends Node3D
## Intro scene: fade in → badge sequence → wait 1s → drop schedule → click
## schedule → proceed to corridor. First ever open: BadgeProp drops in with a
## voice line and the player snaps it into the slot; replays: badge already in
## slot. Props own their own interaction; this script drives the flow and the
## shared table-contact freeze.

const SCHEDULE_DELAY := 1.0
const THROW_TIMEOUT := 3.0

@onready var camera: Camera3D = $Camera3D
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice
@onready var badge: IntroBadge = $BadgeProp
@onready var schedule: IntroSchedule = $ScheduleProp


func _ready() -> void:
	badge.setup(camera, slot, voice)
	schedule.setup(voice)
	schedule.proceed.connect(_on_schedule_proceed)
	await Transition.fade_in()
	if PlayerProfile.intro_seen:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.drop()
	PlayerProfile.mark_intro_seen()
	await badge.placed
	await _wait(SCHEDULE_DELAY)
	schedule.reveal()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then drop schedule.
	badge.place_in_slot()
	await _wait(SCHEDULE_DELAY)
	schedule.reveal()


# ---------------- Table contact ----------------

func _on_table_area_3d_body_entered(body: Node3D) -> void:
	if body == badge:
		badge.freeze = true
	if body == schedule:
		schedule.freeze = true


# ---------------- Schedule transition ----------------
func _on_schedule_proceed() -> void:
	await Transition.fade_out()
	await _wait(SCHEDULE_DELAY)
	get_tree().change_scene_to_file("res://scenes/corridor.tscn")


# ---------------- Helpers ----------------
func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
