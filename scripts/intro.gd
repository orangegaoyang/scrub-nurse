extends Node3D
## Intro scene: fade in → badge sequence → wait 1s → drop schedule → click
## schedule → proceed to corridor. First ever open: BadgeProp drops in with a
## voice line and the player snaps it into the slot; replays: badge already in
## slot. Props own their own interaction; this script drives the flow and the
## shared table-contact freeze.

const SCHEDULE_DELAY := 1.0
const THROW_TIMEOUT := 3.0

@onready var badge: IntroBadge = $BadgeProp
@onready var schedule: IntroSchedule = $ScheduleProp


func _ready() -> void:
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
	badge.start_hint()
	await badge.placed
	await _wait(SCHEDULE_DELAY)
	schedule.reveal()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then drop schedule.
	badge.place_in_slot()
	await _wait(1.0)
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

