extends Node3D
## First-person corridor run: after the intro's focus-zoom drops to black,
## the camera sprints down the modelled hospital corridor, pushes the OR
## doors open and steps into the dark room as the screen fades out and hands
## off to main.tscn. Pure 3D, so it works on every platform (Web included).
## The corridor is hospital_mesh_no_door.glb; the doors are the matching
## left_door.glb / right_door.glb pair (cut from the corridor model with
## their world transforms intact, so they already sit in the frame).
## _place_hospital() aligns the corridor by its own nodes ("surgery frame"
## to the door plane, corridor toward +z); the door hinges are baked into
## the scene, so the editor shows exactly what the game uses. Door/step
## sounds fire
## through Sfx.play("footstep") / Sfx.play("door_open") and stay silent
## until those files exist in res://assets/audio/sfx/. Clicking (interact)
## skips straight to the handoff.

const EYE_Y := 1.6             # camera eye height
const CAM_START_Z := 15.0      # metres from the door at spawn
# Final pacing: brisk but not sprinting (6.0 m/s felt too fast, 3.0 too slow).
const RUN_SPEED := 4.5         # full speed, m/s
const ACCEL_TIME := 1.2        # speed build-up
const BRAKE_DIST := 1.2        # start braking this far from the door
const BRAKE_TIME := 0.8        # QUAD ease-out from RUN_SPEED covers exactly BRAKE_DIST
const TRAVEL_TOTAL := 15.6     # the door plane sits at CAM_START_Z - TRAVEL_TOTAL
const STEP_IN_DIST := 0.25     # quick step through the frame
const STEP_IN_TIME := 0.55
const WALK_SPEED := 1.1        # step-in pace; also drives a gentle walk bob
const BOB_CYCLES_PER_M := 0.6  # ~2.7 steps/sec at RUN_SPEED
const BOB_AMP := 0.05          # vertical head-bob amplitude at full sprint
const SWAY_AMP := 0.0          # side sway disabled (was too distracting)
const ROLL_AMP := 0.0          # head tilt disabled (rotational sway = dizziness)
const SPEED_FOV := 4.0         # subtle extra FOV at speed; too much reads as
							   # moving BACKWARD at the start of the run
const DOOR_OPEN_ANGLE := 105.0
const DOOR_OPEN_TIME := 0.9
const MAIN_SCENE := "res://scenes/main.tscn"

@onready var hospital: Node3D = $Hospital
@onready var camera: Camera3D = $Camera3D
@onready var hinge_l: Node3D = $DoorRig/HingeLeft
@onready var hinge_r: Node3D = $DoorRig/HingeRight

var _speed := 0.0      # current forward speed (m/s); drives bob cadence
var _travel := 0.0     # metres covered from CAM_START_Z
var _bob_phase := 0.0
var _running := false  # _travel integrates _speed only while true
var _last_step := 0    # bob cycle index, for footstep sfx
var _skipped := false


func _ready() -> void:
	camera.position = Vector3(0.0, EYE_Y, CAM_START_Z)
	# Warm the surgery scene in the background while the run plays, so the
	# handoff swaps instantly instead of loading under the black guard.
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	_place_hospital()
	_running = true
	_sequence()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_skip()
		return
	# The bob phase integrates speed so the cadence naturally speeds up and
	# slows down with the run; amplitude scales with speed too.
	_bob_phase += _speed * BOB_CYCLES_PER_M * delta
	_footsteps()
	if _running:
		_travel += _speed * delta
	var spd := _speed / RUN_SPEED  # 0..1 sprint factor
	var step := _step_bob(fposmod(_bob_phase, TAU) / TAU)
	camera.position = Vector3(
		sin(_bob_phase * 0.5) * SWAY_AMP * spd,
		EYE_Y + (step * 2.0 - 1.0) * BOB_AMP * spd,
		CAM_START_Z - _travel)
	camera.rotation = Vector3(0.0, 0.0, sin(_bob_phase) * ROLL_AMP * spd)
	camera.fov = lerpf(camera.fov, 40.0 + SPEED_FOV * spd, min(delta * 6.0, 1.0))


func _step_bob(p: float) -> float:
	# 0..1 step profile: the head DWELLS at the top (stance pause), drops
	# quickly at the footfall, rises again and dwells — the rhythm of a real
	# walk instead of a floating sine.
	if p < 0.15:
		return 1.0 - p / 0.15  # impact: fast drop 1 -> 0
	elif p < 0.55:
		return (p - 0.15) / 0.4  # recovery: rise 0 -> 1
	return 1.0  # dwell at the top until the next footfall


# ---------------- Flow ----------------

func _sequence() -> void:
	await Transition.fade_in(0.5)
	if _skipped:
		return
	# Sprint: build speed, hold it until the braking point.
	var acc := create_tween()
	acc.tween_property(self, "_speed", RUN_SPEED, ACCEL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await acc.finished
	if _skipped:
		return
	while _travel < TRAVEL_TOTAL - BRAKE_DIST:
		await get_tree().process_frame
	_open_doors()  # push the doors open on the way in
	# Brake with ease-out: hard initial decel, then a gentle glide to zero.
	# The integral of the curve is exactly BRAKE_DIST, so the camera comes to
	# rest right on the threshold.
	var brk := create_tween()
	brk.tween_property(self, "_speed", 0.0, BRAKE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await brk.finished
	if _skipped:
		return
	# Step through the frame, then hand off: a beat in the dark room, then
	# the lights snap on — a white flash carries the swap to the surgery
	# scene, which reveals out of the white.
	_running = false
	_speed = WALK_SPEED  # keep a gentle walk bob while stepping in
	var in_tw := create_tween()
	in_tw.tween_property(self, "_travel", TRAVEL_TOTAL + STEP_IN_DIST, STEP_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await in_tw.finished
	await Util.wait(0.4)  # let the dark room register before the lights snap on
	_lights_on_handoff()


func _lights_on_handoff() -> void:
	# The room lights snap on: a white flash covers the dark room and
	# carries the swap to the preloaded surgery scene.
	Sfx.play("light_on")
	await Transition.flash_white(0.22)
	await _swap_to_main()


func _handoff() -> void:
	# Instant cut (skip path): single-frame black guard, then swap.
	Transition.cover_now()
	await _swap_to_main()


func _swap_to_main() -> void:
	# Swap to the preloaded surgery scene. If the threaded load is somehow
	# still running, wait for it (bounded), then fall back to a plain file
	# change.
	var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE)
	var frames := 0
	while packed == null and frames < 600:
		await get_tree().process_frame
		frames += 1
		packed = ResourceLoader.load_threaded_get(MAIN_SCENE)
	if packed == null:
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		get_tree().change_scene_to_packed(packed)


func _open_doors() -> void:
	# Both leaves swing away from the runner into the room.
	Sfx.play("door_open")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(hinge_l, "rotation_degrees:y", DOOR_OPEN_ANGLE, DOOR_OPEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hinge_r, "rotation_degrees:y", -DOOR_OPEN_ANGLE, DOOR_OPEN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# ---------------- Model placement / materials ----------------

func _place_hospital() -> void:
	# Align the model by its own nodes: the "surgery frame" must land on the
	# door plane (z = -0.5) with the corridor extending toward +z and the
	# dark room (far wall "wall.002") on the other side. Deriving the run
	# direction from the model itself makes the placement immune to the
	# glTF importer's Z-flip and to future re-exports.
	var frame := hospital.find_child("surgery frame", true, false) as Node3D
	var back := hospital.find_child("wall.002", true, false) as Node3D
	if frame == null or back == null:
		return
	var dir := frame.position - back.position  # dark room -> corridor
	hospital.rotation = Vector3.ZERO
	if dir.z < 0.0:
		# The corridor lies on the model's -z side: flip it around.
		hospital.rotation.y = PI
		hospital.position = Vector3(0.0, 0.0, frame.position.z - 0.5)
	else:
		hospital.position = Vector3(0.0, 0.0, -frame.position.z - 0.5)


# ---------------- Skip / sound ----------------

func _skip() -> void:
	# Click during the run: cut straight to the handoff. Pending tweens die
	# with this scene, so nothing fights the swap.
	if _skipped:
		return
	_skipped = true
	_handoff()


func _footsteps() -> void:
	# One footfall per full bob cycle (one head dip = one ground contact).
	var step := int(_bob_phase / TAU)
	if step != _last_step:
		_last_step = step
		Sfx.play("footstep")
