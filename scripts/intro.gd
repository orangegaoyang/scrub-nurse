extends Node3D
## Intro:
## Day 1: physics-drop badge → click to pick up (lifts toward camera), mouse
##   follows on the table plane, click to drop → snap into slot if horizontally
##   close, else free-fall back onto the table → wait 1s → arc-throw schedule →
##   click schedule → proceed to corridor.
## Replay (same session): badge already in slot, wait 1s, throw schedule.

const DROP_P0 := Vector3(0.0, 2.5, -1.8)
const DROP_P1 := Vector3(0.0, 1.5, 0.15)
const REST_POS := Vector3(0.0, 1.21, 0.0)
const SLOT_POS := Vector3(0.0, 1.21, -0.14)
const SNAP_DISTANCE := 0.18
const SCHEDULE_DELAY := 1.0
const DROP_TIME := 1.6
const BOUNCE_TIME := 0.34
const BOUNCE_PEAK := 0.06
const TABLE_Y := 1.21
const HOLD_Y := 1.5
const HOLD_X_LIMIT := 0.45
const HOLD_Z_LIMIT := 0.4
const THROW_VY := 1.5
const THROW_VZ := 2.7
const THROW_TIMEOUT := 3.0

# Persists across scene reloads within one process: skip the badge throw on
# replays (badge stays in slot).
static var _intro_seen_once := false

@onready var camera: Camera3D = $Camera3D
@onready var badge: RigidBody3D = $BadgeProp
@onready var schedule: Area3D = $ScheduleProp
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice

var _proceeding: bool = false
var _badge_held: bool = false
var _badge_placed: bool = false
var _pick_frame: int = -1
var _aim_x: float
var _aim_z: float
var _slot_blink: Tween
var _sched_blink: Tween


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	badge.visible = false
	schedule.visible = false
	slot.visible = false
	badge.freeze = true
	badge.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	badge.input_event.connect(_on_badge_input_event)
	await Transition.fade_in()
	if _intro_seen_once:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.visible = true
	await _physics_throw()
	_intro_seen_once = true
	_voice("intro_badge")
	await _wait_for_badge_placed()
	await _wait(SCHEDULE_DELAY)
	await _throw_schedule()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then throw schedule.
	badge.global_position = SLOT_POS + Vector3(0, 0.005, 0)
	badge.visible = true
	_badge_placed = true
	await _wait(1.0)
	await _throw_schedule()


func _throw_schedule() -> void:
	schedule.visible = true
	await _arc_throw(schedule)
	schedule.input_event.connect(_on_schedule_input_event)
	_voice("intro_schedule")
	_start_schedule_blink()


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
	if not _badge_held:
		return
	# Drive the drag on the physics timeline so the body's transform doesn't
	# fight the physics server (which would jitter when set from _input).
	var cur := badge.global_position
	var ty := lerpf(cur.y, HOLD_Y, clampf(delta * 18.0, 0.0, 1.0))
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
	var horiz := Vector2(badge.global_position.x - SLOT_POS.x, badge.global_position.z - SLOT_POS.z).length()
	if horiz < SNAP_DISTANCE:
		var snap := create_tween()
		snap.tween_property(badge, "global_position", SLOT_POS + Vector3(0, 0.005, 0), 0.22) \
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
		await _settle_and_freeze()


func _wait_for_badge_placed() -> void:
	while not _badge_placed:
		await get_tree().process_frame


# ---------------- Schedule interaction ----------------

func _on_schedule_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceeding = true
		_stop_schedule_blink()
		await Transition.fade_out()
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://scenes/corridor.tscn")


# ---------------- Helpers ----------------

func _physics_throw() -> void:
	badge.global_position = DROP_P0
	badge.rotation = Vector3.ZERO
	badge.freeze = false
	badge.sleeping = false
	badge.linear_velocity = Vector3(0.0, THROW_VY, THROW_VZ)
	badge.angular_velocity = Vector3.ZERO
	await _settle_and_freeze()


func _settle_and_freeze() -> void:
	var elapsed := 0.0
	while not badge.sleeping and elapsed < THROW_TIMEOUT:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	badge.freeze = true
	badge.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	badge.linear_velocity = Vector3.ZERO
	badge.angular_velocity = Vector3.ZERO
	badge.rotation = Vector3.ZERO

func _arc_throw(node: Node3D) -> void:
	var arc := create_tween()
	arc.tween_method(
		func(t: float):
			var u := 1.0 - t
			node.global_position = u * u * DROP_P0 + 2 * u * t * DROP_P1 + t * t * REST_POS,
		0.0, 1.0, DROP_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await arc.finished
	var bounce := create_tween()
	bounce.tween_property(node, "global_position", REST_POS + Vector3(0, BOUNCE_PEAK, 0), BOUNCE_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(node, "global_position", REST_POS, BOUNCE_TIME * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await bounce.finished


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
	_slot_blink.tween_property(mat, "albedo_color:a", 0.15, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_blink.tween_property(mat, "albedo_color:a", 0.6, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_slot_blink() -> void:
	if _slot_blink:
		_slot_blink.kill()
		_slot_blink = null
	var mat: StandardMaterial3D = slot.material_override
	if mat:
		var c: Color = mat.albedo_color
		c.a = 0.4
		mat.albedo_color = c


func _start_schedule_blink() -> void:
	_stop_schedule_blink()
	_sched_blink = create_tween().set_loops()
	_sched_blink.tween_property(schedule, "scale", Vector3(1.04, 1.04, 1.04), 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sched_blink.tween_property(schedule, "scale", Vector3.ONE, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_schedule_blink() -> void:
	if _sched_blink:
		_sched_blink.kill()
		_sched_blink = null
	schedule.scale = Vector3.ONE


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
