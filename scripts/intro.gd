extends Node3D
## Intro:
## Day 1: physics-drop badge → click to pick up (lifts toward camera), mouse
##   follows on the table plane, click to drop → snap into slot if horizontally
##   close, else free-fall back onto the table → wait 1s → physics-drop schedule
##   → click schedule → proceed to corridor.
## Replay (same session): badge already in slot, wait 1s, throw schedule.

const DROP_P0 := Vector3(0.0, 2.5, -1.8)
const SNAP_DISTANCE := 0.22
const SCHEDULE_DELAY := 1.0
const TABLE_Y := 1.21
const HOLD_Y := 1.65
const REST_SCALE := 0.5
const HOLD_SCALE := 1.0
const HOLD_X_LIMIT := 0.45
const HOLD_Z_LIMIT := 0.4
const THROW_VY := 1.5
const REST_Y := 1.3 # table top (1.2) + half collision-box height (0.1)
const THROW_TIMEOUT := 3.0
const SCHEDULE_LAND := Vector3(0.0, 0.0, 0.12) # lower half of the table, clear of the slot

# Persists across scene reloads within one process: skip the badge throw on
# replays (badge stays in slot).
static var _intro_seen_once := false

@onready var camera: Camera3D = $Camera3D
@onready var badge: RigidBody3D = $BadgeProp
@onready var badge_mesh: MeshInstance3D = $BadgeProp/Mesh
@onready var schedule: RigidBody3D = $ScheduleProp
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice

var _proceeding: bool = false
var _badge_held: bool = false
var _badge_placed: bool = false
var _pick_frame: int = -1
var _aim_x: float
var _aim_z: float
var _slot_blink: Tween


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	badge.visible = false
	schedule.visible = false
	slot.visible = false
	badge_mesh.scale = Vector3.ONE * REST_SCALE
	badge.freeze = true
	badge.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	schedule.freeze = true
	schedule.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	badge.input_event.connect(_on_badge_input_event)
	await Transition.fade_in()
	if _intro_seen_once:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.visible = true
	await _physics_throw(badge, Vector3.ZERO)
	_intro_seen_once = true
	_voice("intro_badge")
	await _wait_for_badge_placed()
	await _wait(SCHEDULE_DELAY)
	await _throw_schedule()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then throw schedule.
	badge.global_position = slot.global_position + Vector3(0, 0.005, 0)
	badge.visible = true
	_badge_placed = true
	await _wait(1.0)
	await _throw_schedule()


func _throw_schedule() -> void:
	schedule.visible = true
	await _physics_throw(schedule, SCHEDULE_LAND)
	# Physics bounce drifts the landing; slide to a precise spot clear of the badge.
	var slide := create_tween()
	slide.tween_property(schedule, "global_position",
		Vector3(SCHEDULE_LAND.x, REST_Y, SCHEDULE_LAND.z), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await slide.finished
	schedule.input_event.connect(_on_schedule_input_event)
	_voice("intro_schedule")


# ---------------- Badge interaction ----------------

func _on_badge_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _badge_placed or _badge_held or not badge.freeze:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_badge_held = true
		_pick_frame = Engine.get_process_frames()
		# Seed the aim with the current rest position so the badge lifts in place.
		_aim_x = badge.global_position.x
		_aim_z = badge.global_position.z
		slot.visible = true
		_start_slot_blink()


func _physics_process(delta: float) -> void:
	var f := clampf(delta * 18.0, 0.0, 1.0)
	var ts := HOLD_SCALE if _badge_held else REST_SCALE
	badge_mesh.scale = badge_mesh.scale.lerp(Vector3.ONE * ts, f)
	if not _badge_held:
		return
	# Drive the drag on the physics timeline so the body's transform doesn't
	# fight the physics server (which would jitter when set from _input).
	var cur := badge.global_position
	var ty := lerpf(cur.y, HOLD_Y, f)
	badge.global_position = Vector3(_aim_x, ty, _aim_z)


func _input(event: InputEvent) -> void:
	if not _badge_held:
		return
	if event is InputEventMouseMotion:
		var aim := _mouse_to_plane(event.position, TABLE_Y)
		if aim != Vector3.INF:
			_aim_x = clampf(aim.x, -HOLD_X_LIMIT, HOLD_X_LIMIT)
			_aim_z = clampf(aim.z, -HOLD_Z_LIMIT, HOLD_Z_LIMIT)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Engine.get_process_frames() == _pick_frame:
			return  # same frame as the pick press; ignore
		_badge_held = false
		_drop_badge()


func _drop_badge() -> void:
	_stop_slot_blink()
	# Horizontal aim decides the snap; hold height is irrelevant.
	var sp := slot.global_position
	var horiz := Vector2(badge.global_position.x - sp.x, badge.global_position.z - sp.z).length()
	if horiz < SNAP_DISTANCE:
		var snap := create_tween()
		snap.tween_property(badge, "global_position", sp + Vector3(0, 0.005, 0), 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await snap.finished
		_badge_placed = true
		slot.visible = false
	else:
		# Let go: free-fall back onto the table, then re-freeze for picking.
		badge.freeze = false
		badge.sleeping = false
		badge.linear_velocity = Vector3.ZERO
		badge.angular_velocity = Vector3.ZERO
		await _settle_and_freeze(badge)


func _wait_for_badge_placed() -> void:
	while not _badge_placed:
		await get_tree().process_frame


# ---------------- Schedule interaction ----------------

func _on_schedule_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding or not schedule.freeze:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceeding = true
		await Transition.fade_out()
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://scenes/corridor.tscn")


# ---------------- Helpers ----------------

func _physics_throw(body: RigidBody3D, target: Vector3) -> void:
	body.global_position = DROP_P0
	body.rotation = Vector3.ZERO
	body.freeze = false
	body.sleeping = false
	var t := _flight_time()
	body.linear_velocity = Vector3(
		(target.x - DROP_P0.x) / t,
		THROW_VY,
		(target.z - DROP_P0.z) / t)
	body.angular_velocity = Vector3.ZERO
	await _settle_and_freeze(body)


func _flight_time() -> float:
	# REST_Y = DROP_P0.y + THROW_VY*t - (g/2)*t^2  (g = 9.8); solve for t > 0.
	var a := 4.9
	var b := -THROW_VY
	var c := REST_Y - DROP_P0.y
	return (-b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a)


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


func _mouse_to_plane(mouse_pos: Vector2, plane_y: float) -> Vector3:
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - from.y) / dir.y
	if t < 0:
		return Vector3.INF
	return from + dir * t


func _start_slot_blink() -> void:
	_stop_slot_blink()
	var mat: StandardMaterial3D = slot.material_override
	_slot_blink = create_tween().set_loops()
	_slot_blink.tween_property(mat, "albedo_color:a", 0.4, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_blink.tween_property(mat, "albedo_color:a", 0.95, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_slot_blink() -> void:
	if _slot_blink:
		_slot_blink.kill()
		_slot_blink = null
	var mat: StandardMaterial3D = slot.material_override
	if mat:
		var c: Color = mat.albedo_color
		c.a = 0.6
		mat.albedo_color = c


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
