class_name IntroBadge
extends RigidBody3D
## The badge prop in the intro scene. Handles pick-up, drag, drop, and snap
## into the slot. The intro scene calls drop() on the first ever open (badge
## falls in + voice line) or place_in_slot() on replays; emits `placed` when
## the player snaps it in. Dependencies (camera, slot, voice) are injected via
## setup().

signal placed

const SNAP_DISTANCE := 0.14
const HOLD_Y := 1.65
const HOLD_SCALE := 2.0
const HOLD_X_LIMIT := 0.45
const HOLD_Z_LIMIT := 0.4
const VOICE_KEY := "intro_badge"

@onready var mesh: MeshInstance3D = $Mesh
@onready var hint: MeshInstance3D = $BadgeHint

var _slot: MeshInstance3D
var _camera: Camera3D
var _voice: AudioStreamPlayer
var _rest_size: Vector2
var _held: bool = false
var _placing: bool = false
var _pick_frame: int = -1
var _slot_blink: Tween
var _hint_blink: Tween


func _ready() -> void:
	visible = false
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hint.visible = false
	input_event.connect(_on_input_event)
	# Cache the mesh's authored rest size from the scene before _physics_process
	# starts overwriting it with the lerp.
	var pm: PlaneMesh = mesh.mesh
	_rest_size = pm.size


func setup(camera: Camera3D, slot: MeshInstance3D, voice: AudioStreamPlayer) -> void:
	_camera = camera
	_slot = slot
	_slot.visible = false
	_voice = voice


func drop() -> void:
	# First-ever open: reveal, release physics so the badge drops in, voice it.
	visible = true
	freeze = false
	Util.play_voice(_voice, VOICE_KEY)
	_start_hint()


func place_in_slot() -> void:
	# Replay path: badge already belongs in the slot.
	global_position = _slot.global_position + Vector3(0, 0.005, 0)
	visible = true


# ---------------- Interaction ----------------

func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _held or _placing :
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_held = true
		_pick_frame = Engine.get_process_frames()
		_slot.visible = true
		freeze = true
		_start_slot_blink()
		_stop_hint_blink()


func _physics_process(delta: float) -> void:
	var f := clampf(delta * 18.0, 0.0, 1.0)
	var pm: PlaneMesh = mesh.mesh
	var target := (_rest_size * HOLD_SCALE) if _held else _rest_size
	pm.size = pm.size.lerp(target, f)
	if not _held:
		return
	# Track the cursor every physics frame, projecting onto the badge's own
	# rising height — this keeps it glued through the lift (parallax shifts as
	# it rises) without relying on mouse-motion events, which arrived too late
	# and caused a visible jump after the pickup "lift in place".
	var cur := global_position
	var ty := lerpf(cur.y, HOLD_Y, f)
	var aim := _mouse_to_plane(get_viewport().get_mouse_position(), ty)
	if aim != Vector3.INF:
		global_position = Vector3(
			clampf(aim.x, -HOLD_X_LIMIT, HOLD_X_LIMIT),
			ty,
			clampf(aim.z, -HOLD_Z_LIMIT, HOLD_Z_LIMIT))


func _input(event: InputEvent) -> void:
	if not _held:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#if Engine.get_process_frames() == _pick_frame:
			#return  # same frame as the pick press; ignore
		_held = false
		freeze = false
	
		_stop_slot_blink()
		_drop()


func _drop() -> void:
	# Project the cursor onto the table for BOTH the snap check and the landing
	# spot. The badge hovers at HOLD_Y, so its own x/z is parallax-offset from
	# where the cursor points on the table — comparing badge.xz to the slot
	# (the old code) made the snap miss even when the cursor was right on it.
	var tp := _mouse_to_plane(get_viewport().get_mouse_position(), _slot.position.y)
	if tp == Vector3.INF:
		return  # cursor off the table plane — nowhere to drop
	var sp := _slot.global_position
	var horiz := Vector2(tp.x - sp.x, tp.z - sp.z).length()
	if horiz < SNAP_DISTANCE:
		_placing = true
		var snap := create_tween()
		snap.tween_property(self, "global_position", sp + Vector3(0, 0.005, 0), 0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await snap.finished
		_slot.visible = false
		placed.emit()
		_placing = false
	else:
		# Missed the slot: lower the badge to where the cursor points on the table.
		_placing = true
		var land := create_tween()
		land.tween_property(self, "global_position", Vector3(
			clampf(tp.x, -HOLD_X_LIMIT, HOLD_X_LIMIT),
			_slot.position.y,
			clampf(tp.z, -HOLD_Z_LIMIT, HOLD_Z_LIMIT)), 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await land.finished
		_placing = false
	


# ---------------- Helpers ----------------

func _mouse_to_plane(mouse_pos: Vector2, plane_y: float) -> Vector3:
	var from := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - from.y) / dir.y
	if t < 0:
		return Vector3.INF
	return from + dir * t


func _start_hint() -> void:
	Util.wait(2)
	hint.visible = true
	var mat: ShaderMaterial = hint.material_override
	_hint_blink = create_tween().set_loops()
	_hint_blink.tween_property(mat, "shader_parameter/alpha", 0.7, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_blink.tween_property(mat, "shader_parameter/alpha", 0.3, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_slot_blink() -> void:
	_stop_slot_blink()
	_slot.visible = true
	var mat: StandardMaterial3D = _slot.material_override
	_slot_blink = create_tween().set_loops()
	_slot_blink.tween_property(mat, "albedo_color:a", 0.7, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_blink.tween_property(mat, "albedo_color:a", 0.3, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_slot_blink() -> void:
	if _slot_blink:
		_slot.visible = false
		_slot_blink.kill()
		_slot_blink = null
	var mat: StandardMaterial3D = _slot.material_override
	if mat:
		var c: Color = mat.albedo_color
		c.a = 0.4
		mat.albedo_color = c


func _stop_hint_blink() -> void:
	if _hint_blink:
		_hint_blink.kill()
		_hint_blink = null
	hint.visible = false
