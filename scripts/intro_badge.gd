class_name IntroBadge
extends RigidBody3D
## The badge prop in the intro scene. Handles pick-up, drag, drop, and snap
## into the slot. Emits `placed` when the player drops it close enough to
## the slot. The intro scene script drives the throw and the overall flow.

signal placed

const DROP_P0 := Vector3(0.0, 2.5, -1.8)

const SNAP_DISTANCE := 0.14
const TABLE_Y := 1.21
const HOLD_Y := 1.65
const REST_MESH_SIZE := Vector2(0.15, 0.09)
const HOLD_MESH_SIZE := Vector2(0.3, 0.18)
const HOLD_X_LIMIT := 0.45
const HOLD_Z_LIMIT := 0.4
const SETTLE_TIMEOUT := 3.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var hint: MeshInstance3D = $BadgeHint

var _camera: Camera3D
var _slot: MeshInstance3D
var _held: bool = false
var _placing: bool = false
var _pick_frame: int = -1
var _aim_x: float
var _aim_z: float
var _slot_blink: Tween
var _hint_blink: Tween


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hint.visible = false
	input_event.connect(_on_input_event)


func setup(camera: Camera3D, slot: MeshInstance3D) -> void:
	_camera = camera
	_slot = slot


func place_in_slot() -> void:
	# Replay path: badge already belongs in the slot.
	global_position = _slot.global_position + Vector3(0, 0.005, 0)
	visible = true


func start_hint() -> void:
	hint.visible = true
	var mat: ShaderMaterial = hint.material_override
	_hint_blink = create_tween().set_loops()
	_hint_blink.tween_property(mat, "shader_parameter/alpha", 0.7, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_blink.tween_property(mat, "shader_parameter/alpha", 0.3, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------- Interaction ----------------

func _on_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _held or _placing or not freeze:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_held = true
		_pick_frame = Engine.get_process_frames()
		# Seed the aim with the current rest position so the badge lifts in place.
		_aim_x = global_position.x
		_aim_z = global_position.z
		_slot.visible = true
		_start_slot_blink()
		_stop_hint_blink()


func _physics_process(delta: float) -> void:
	var f := clampf(delta * 18.0, 0.0, 1.0)
	var pm: PlaneMesh = mesh.mesh
	var target := HOLD_MESH_SIZE if _held else REST_MESH_SIZE
	pm.size = pm.size.lerp(target, f)
	if not _held:
		return
	# Drive the drag on the physics timeline so the body's transform doesn't
	# fight the physics server (which would jitter when set from _input).
	var cur := global_position
	var ty := lerpf(cur.y, HOLD_Y, f)
	global_position = Vector3(_aim_x, ty, _aim_z)


func _input(event: InputEvent) -> void:
	if not _held:
		return
	if event is InputEventMouseMotion:
		var aim := _mouse_to_plane(event.position, TABLE_Y)
		if aim != Vector3.INF:
			_aim_x = clampf(aim.x, -HOLD_X_LIMIT, HOLD_X_LIMIT)
			_aim_z = clampf(aim.z, -HOLD_Z_LIMIT, HOLD_Z_LIMIT)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Engine.get_process_frames() == _pick_frame:
			return  # same frame as the pick press; ignore
		_held = false
		_drop()


func _drop() -> void:
	_stop_slot_blink()
	# Horizontal aim decides the snap; hold height is irrelevant.
	var sp := _slot.global_position
	var horiz := Vector2(global_position.x - sp.x, global_position.z - sp.z).length()
	if horiz < SNAP_DISTANCE:
		_placing = true
		var snap := create_tween()
		snap.tween_property(self, "global_position", sp + Vector3(0, 0.005, 0), 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await snap.finished
		_slot.visible = false
		placed.emit()
		_placing = false
	else:
		# Let go: free-fall back onto the table, then re-freeze for picking.
		freeze = false
		sleeping = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		await _settle_and_freeze()


# ---------------- Helpers ----------------

func _settle_and_freeze() -> void:
	var elapsed := 0.0
	while not sleeping and elapsed < SETTLE_TIMEOUT:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = Vector3.ZERO


func _mouse_to_plane(mouse_pos: Vector2, plane_y: float) -> Vector3:
	var from := _camera.project_ray_origin(mouse_pos)
	var dir := _camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - from.y) / dir.y
	if t < 0:
		return Vector3.INF
	return from + dir * t


func _start_slot_blink() -> void:
	_stop_slot_blink()
	var mat: StandardMaterial3D = _slot.material_override
	_slot_blink = create_tween().set_loops()
	_slot_blink.tween_property(mat, "albedo_color:a", 0.7, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_blink.tween_property(mat, "albedo_color:a", 0.3, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_slot_blink() -> void:
	if _slot_blink:
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
