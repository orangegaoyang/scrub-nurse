extends Node3D
## Intro scene: fade in → badge sequence → wait 1s → lay down schedule →
## click a surgery row → proceed to corridor. First ever open: BadgeProp
## drops in with a voice line and the player snaps it into the slot; replays:
## badge already in slot. Props own their own interaction and idle
## micro-animations; this script drives the flow, the ambient light pulse,
## and the transition out.

const SCHEDULE_DELAY := 1.8  # badge placed → paper laid down

@onready var camera: Camera3D = $Camera3D
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice
@onready var badge: IntroBadge = $BadgeProp
@onready var schedule: IntroSchedule = $ScheduleProp
@onready var backdrop: Sprite3D = $Camera3D/Backdrop

# Sun/cloud breathing on the backdrop only: the window light in the bg image
# slowly drifts between full sun and a cool cloud shade, lingering a random
# while at each extreme. The desk itself is not touched, so the change can be
# big without washing out the scene.
const BACKDROP_SUN := Color(1.0, 1.0, 1.0)
const BACKDROP_CLOUD := Color(0.7, 0.74, 0.82)
const DRIFT_MIN := 4.0  # seconds per sun↔cloud transition
const DRIFT_MAX := 6.0
const DWELL_MIN := 2.0  # random linger at each extreme
const DWELL_MAX := 4.0


func _ready() -> void:
	$BGM.play()
	badge.setup(camera, slot, voice)
	schedule.setup(voice, camera)
	schedule.proceed.connect(_on_schedule_proceed)
	badge.held_changed.connect(schedule.set_badge_held)
	# Desk decorations: hand them the camera for their faint parallax.
	for prop in $Decration.get_children():
		if prop is IntroProp:
			prop.setup(camera)
	_light_cycle()
	await Transition.fade_in()
	if PlayerProfile.intro_seen:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Ambient light ----------------

func _light_cycle() -> void:
	# Sun: drift back to full window light, then linger a random while.
	var sun := create_tween()
	sun.tween_property(backdrop, "modulate", BACKDROP_SUN, randf_range(DRIFT_MIN, DRIFT_MAX)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await sun.finished
	await Util.wait(randf_range(DWELL_MIN, DWELL_MAX))
	# Cloud: a cool grey shade drifts across the windows, then lingers.
	var cloud := create_tween()
	cloud.tween_property(backdrop, "modulate", BACKDROP_CLOUD, randf_range(DRIFT_MIN, DRIFT_MAX)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await cloud.finished
	await Util.wait(randf_range(DWELL_MIN, DWELL_MAX))
	_light_cycle()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.drop()
	await badge.placed
	PlayerProfile.mark_intro_seen()
	await Util.wait(SCHEDULE_DELAY)
	_reveal_schedule()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then lay down the schedule.
	badge.place_in_slot()
	await Util.wait(SCHEDULE_DELAY)
	_reveal_schedule()


func _reveal_schedule() -> void:
	schedule.reveal()
	_shake_desk()  # the desk bumps as the paper slides down


# ---------------- Desk nudge ----------------

func _shake_desk() -> void:
	# The paper landing gives the whole desk a barely-there nudge, staggered
	# across the decorations like a ripple.
	for prop in get_tree().get_nodes_in_group("desk_prop"):
		prop.shake()
		await Util.wait(0.02)


# ---------------- Schedule transition ----------------

func _on_schedule_proceed(index: int, entry: Dictionary) -> void:
	# Remember which surgery the player picked for the day, then move on.
	GameState.selected_surgery_index = index
	GameState.selected_surgery = entry
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	await Transition.fade_out()
	await Util.wait(SCHEDULE_DELAY)
	get_tree().change_scene_to_file("res://scenes/corridor.tscn")
