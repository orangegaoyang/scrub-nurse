class_name IntroBadge
extends RigidBody3D
## The badge prop in the intro scene. Handles pick-up, drag, drop, snap into
## the slot, plus the idle micro-animations once placed: a gentle breathing
## rock and a barely-there mouse parallax, a pickup swell and a cursor sway,
## and an ease-out-back return on release. The intro scene
## calls drop() on the first ever open (badge falls in + voice line) or
## place_in_slot() on replays; emits `placed` when the player snaps it in.
## Dependencies (camera, slot, voice) are injected via setup(). The hint and
## slot glow affordances live in badge_glow.gd (BadgeGlow component).

signal placed
signal held_changed(held: bool)  # so the schedule can suppress row hover during a drag

const SNAP_DISTANCE := 0.14
const HOLD_Y := 1.65
const HOLD_X_LIMIT := 0.45
const HOLD_Z_LIMIT := 0.4
# Height the badge rests at when placed: table top (1.2) + half the collision
# box thickness. Placing at the exact rest height and freezing the body keeps
# it from ever falling/sinking into the table (a live dynamic body with a
# 0.005-thick box settles partially inside the StaticBody on every drop and
# the mesh ends up under the table surface — the badge "disappears").
const REST_Y := 1.2025
const VOICE_KEY := "intro_badge"

# ---------------- Micro-animation tuning ----------------
const BREATHE_ANGLE := 1.0  # degrees, idle rocking amplitude
const BREATHE_CYCLE := 3.0  # seconds per full rock (sine in/out)
const PICK_SCALE := 2.0  # scale while held (matches the original 2× lift)
const PICK_SCALE_TIME := 0.15
const SWAY_ANGLE := 3.0  # degrees, max cursor sway while held
const DROP_BACK_TIME := 0.4  # ease-out-back return on release
const PARALLAX_PX := 3.0  # idle mouse parallax, screen pixels
const REST_SPEED := 0.02  # linear velocity under which a fallen badge rests

@onready var fx: Node3D = $FX  # visual pivot: breathing rock, pick scale, cursor sway
@onready var mesh: MeshInstance3D = $FX/Mesh
@onready var hint: MeshInstance3D = $BadgeHint

var _slot: MeshInstance3D
var _camera: Camera3D
var _voice: AudioStreamPlayer
var _held: bool = false
var _placing: bool = false
var _settled: bool = false
var _pick_frame: int = -1
var _rest_pos: Vector3
var _rest_rot: Vector3
var _par: Vector3 = Vector3.ZERO
var _breathe: Tween
var _fx_return: Tween
var _glow: BadgeGlow  # hint + slot glow affordances (badge_glow.gd)


func _ready() -> void:
	visible = false
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_glow = BadgeGlow.new()
	add_child(_glow)


func setup(camera: Camera3D, slot: MeshInstance3D, voice: AudioStreamPlayer) -> void:
	_camera = camera
	_slot = slot
	_voice = voice
	_glow.setup(hint, _slot)


func drop() -> void:
	# First-ever open: reveal, release physics so the badge drops in, voice it.
	visible = true
	freeze = false
	Util.play_voice(_voice, VOICE_KEY)
	_glow.show_when_rested()


func place_in_slot() -> void:
	# Replay path: badge already belongs in the slot.
	_snap_to_slot()
	visible = true
	_on_settled()


# ---------------- Interaction ----------------

func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _held or _placing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_held = true
		held_changed.emit(true)
		_settled = false
		_pick_frame = Engine.get_process_frames()
		freeze = true
		_glow.slot_on()
		_glow.dismiss()
		_on_pick()


func _on_pick() -> void:
	# Pickup juice: swell to PICK_SCALE and hand the pivot rotation over to
	# the cursor sway.
	_stop_breathing()
	if _fx_return:
		_fx_return.kill()
		_fx_return = null
	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * PICK_SCALE, PICK_SCALE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _held:
		_update_hold(delta)
		return
	if _placing:
		return
	if _settled:
		_apply_parallax(delta)
		return
	# First-open fall: freeze as soon as the badge comes to rest on the table
	# so the idle state (breathing + parallax) can take over. The height check
	# keeps the freshly-released body (velocity still zero, still in the air)
	# from freezing mid-drop.
	if not freeze and global_position.y <= REST_Y + 0.005 and linear_velocity.length() < REST_SPEED:
		freeze = true
		# Record where the badge landed so right-click cancel can glide back.
		# Breathing/parallax start only once the badge is in the slot.
		_capture_rest_pose()


func _update_hold(delta: float) -> void:
	# Track the cursor every physics frame, projecting onto the badge's own
	# rising height — this keeps it glued through the lift without relying on
	# mouse-motion events, which arrived too late and caused a visible jump
	# after the pickup "lift in place".
	var f := clampf(delta * 18.0, 0.0, 1.0)
	var cur := global_position
	var ty := lerpf(cur.y, HOLD_Y, f)
	var aim := Util.mouse_to_plane(_camera, get_viewport().get_mouse_position(), ty)
	if aim != Vector3.INF:
		global_position = Vector3(
			clampf(aim.x, -HOLD_X_LIMIT, HOLD_X_LIMIT),
			ty,
			clampf(aim.z, -HOLD_Z_LIMIT, HOLD_Z_LIMIT))
	# Cursor sway: tilt ±SWAY_ANGLE with the cursor's screen position.
	var n := Util.normalized_mouse(
		get_viewport().get_mouse_position(), get_viewport().get_visible_rect().size)
	var target := Vector3(n.y * SWAY_ANGLE, -n.x * SWAY_ANGLE, 0.0)
	fx.rotation_degrees = fx.rotation_degrees.lerp(target, clampf(delta * 12.0, 0.0, 1.0))


func _apply_parallax(delta: float) -> void:
	_par = _par.lerp(Util.parallax_offset(_camera, REST_Y, PARALLAX_PX), clampf(delta * 8.0, 0.0, 1.0))
	global_position = _rest_pos + _par


func _input(event: InputEvent) -> void:
	if not _held:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Engine.get_process_frames() == _pick_frame:
			return  # same frame as the pick press; ignore
		_held = false
		held_changed.emit(false)
		_glow.slot_off()
		_drop()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click cancels the drag: the pick just never happened.
		_held = false
		held_changed.emit(false)
		_glow.slot_off()
		_cancel_hold()


func _cancel_hold() -> void:
	# Glide the badge back to where it was resting, no snap check, no
	# `placed` — then resume the idle state (breathing + parallax).
	_placing = true
	_start_fx_return()
	var back := create_tween().set_parallel(true)
	back.tween_property(self, "global_position", Vector3(_rest_pos.x, REST_Y, _rest_pos.z), 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	back.tween_property(self, "global_rotation", _rest_rot, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await back.finished
	freeze = true
	_placing = false
	_on_settled()


func _start_fx_return() -> void:
	# Release/cancel juice: ease-out-back the pick swell and cursor sway home.
	_fx_return = create_tween().set_parallel(true)
	_fx_return.tween_property(fx, "scale", Vector3.ONE, DROP_BACK_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx_return.tween_property(fx, "rotation_degrees", Vector3.ZERO, DROP_BACK_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drop() -> void:
	# Ease the swell/sway home, then project the cursor onto the table for
	# BOTH the snap check and the landing spot (the badge hovers at HOLD_Y,
	# so its own x/z is parallax-offset from where the cursor points).
	_start_fx_return()
	var tp := Util.mouse_to_plane(_camera, get_viewport().get_mouse_position(), REST_Y)
	if tp == Vector3.INF:
		return  # cursor off the table plane — nowhere to drop
	var sp := _slot.global_position
	var horiz := Vector2(tp.x - sp.x, tp.z - sp.z).length()
	_placing = true
	if horiz < SNAP_DISTANCE:
		# Freeze at the rest height so the badge never falls into the table
		# (see REST_Y). The 0-duration tween keeps _placing set through the
		# same press's input_event step, so the drop can't double as a pick.
		var snap := create_tween()
		snap.tween_property(self, "global_position", Vector3(sp.x, REST_Y, sp.z), 0)
		await snap.finished
		freeze = true
		_snap_to_slot()
		_glow.slot_off()
		placed.emit()
		_on_settled()
	_placing = false


func _on_settled() -> void:
	# Idle state after the slot snap: lock the base pose for
	# parallax/right-click cancel and start the breathing rock once the
	# release animation settles.
	_settled = true
	_capture_rest_pose()
	if _fx_return and _fx_return.is_valid():
		await Util.wait(DROP_BACK_TIME)
		if not _settled:
			return  # picked up again while easing back
	_start_breathing()


# ---------------- Breathing ----------------

func _capture_rest_pose() -> void:
	# Remember where the badge is resting so parallax and right-click cancel
	# always work from a stable base, even before the first slot snap.
	_rest_pos = global_position
	_rest_rot = global_rotation


func _start_breathing() -> void:
	# Gentle hanging rock: 0 → -1° → +1° → 0 with sine ease in/out, looping,
	# so the badge looks like it's resting loose on the table.
	_stop_breathing()
	var half := BREATHE_CYCLE / 2.0
	_breathe = create_tween()
	_breathe.tween_property(fx, "rotation_degrees:x", -BREATHE_ANGLE, half * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe.tween_property(fx, "rotation_degrees:x", BREATHE_ANGLE, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe.tween_property(fx, "rotation_degrees:x", 0.0, half * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe.set_loops()


func _stop_breathing() -> void:
	if _breathe:
		_breathe.kill()
		_breathe = null


# ---------------- Helpers ----------------

func _snap_to_slot() -> void:
	# Position at the slot's x/z and match its yaw so the badge lands at the
	# angle the slot was rotated to in the editor. Keep it flat on the table.
	global_position = Vector3(_slot.global_position.x, REST_Y, _slot.global_position.z)
	global_rotation = Vector3(0, _slot.global_rotation.y, 0)


func _on_mouse_entered() -> void:
	# Hover confirmation: the glow flares once and the cursor becomes a hand.
	_glow.flare()


func _on_mouse_exited() -> void:
	_glow.settle()
