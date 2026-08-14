class_name IntroSchedule
extends RigidBody3D
## The surgery list board in the intro scene. Renders a 2D SurgeryList (paper
## background + one row per entry in data/surgery.json) into a SubViewport and
## displays it on the board mesh. Call reveal() to lay the paper on the table
## with a staff-placed settle animation. Each list row is an individual click
## target: clicking one emits `proceed(index, entry)` so the intro scene can
## start the day with that surgery. The board also has a hover swell and a
## faint mouse parallax.

signal proceed(index: int, entry: Dictionary)

const SURGERY_LIST := preload("res://scenes/ui/surgery_list.tscn")
const VIEW_SIZE := Vector2i(934, 1010)  # matches surgery.png
const VOICE_KEY := "intro_schedule"

# ---------------- Micro-animation tuning ----------------
const REST_Y := 1.2025  # table top + half the collision box thickness
const SETTLE_TIME := 0.4  # paper lay-down animation
const SETTLE_DROP := 0.0045  # ≈10 px on the 1010 px paper, world units
const SETTLE_TILT := 2.0  # extra paper yaw at settle start (degrees)
const HOVER_SCALE := 1.02
const HOVER_TIME := 0.15
const PARALLAX_PX := 1.0  # idle mouse parallax, screen px (badge: 3 px)

@onready var mesh: MeshInstance3D = $Mesh

var _proceeding: bool = false
var _revealed: bool = false
var _hovered: bool = false
var _badge_held: bool = false  # no row hover while the badge is being dragged
var _voice: AudioStreamPlayer
var _camera: Camera3D
var _viewport: SubViewport
var _list: SurgeryList
var _mat: StandardMaterial3D
var _hover_tw: Tween
var _rest_yaw: float
var _rest_x: float
var _rest_z: float
var _par: Vector3 = Vector3.ZERO


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	visible = false
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_rest_x = global_position.x
	_rest_z = global_position.z
	_rest_yaw = global_rotation.y
	_build_list()


func setup(voice: AudioStreamPlayer, camera: Camera3D) -> void:
	_voice = voice
	_camera = camera


func set_badge_held(held: bool) -> void:
	## The badge drag owns the cursor; suppress row hover while it runs.
	_badge_held = held
	if held:
		_list.set_hover_row(-1)


func reveal() -> void:
	# Lay the paper on the table like a staff member just placed it: fade in
	# a hair above the rest pose, tilted, and settle over SETTLE_TIME. The
	# board stays frozen (kinematic) for the whole scene.
	visible = true
	Util.play_voice(_voice, VOICE_KEY)
	global_position = Vector3(_rest_x, REST_Y - SETTLE_DROP, _rest_z)
	global_rotation.y = _rest_yaw - deg_to_rad(SETTLE_TILT)
	_mat.albedo_color.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position:y", REST_Y, SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_rotation:y", _rest_yaw, SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mat, "albedo_color:a", 1.0, SETTLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_revealed = true


func _process(delta: float) -> void:
	if not _revealed or _proceeding:
		return
	_par = _par.lerp(Util.parallax_offset(_camera, REST_Y, PARALLAX_PX), clampf(delta * 8.0, 0.0, 1.0))
	global_position = Vector3(_rest_x, REST_Y, _rest_z) + _par
	_update_row_hover()


func _update_row_hover() -> void:
	# Poll the cursor every frame (the same ray-cast the badge drag uses)
	# instead of relying on mouse-motion input_event delivery, which proved
	# flaky over a kinematic body that gets repositioned every frame.
	if _badge_held:
		return
	var tp := Util.mouse_to_plane(_camera, get_viewport().get_mouse_position(), REST_Y)
	var index := -1
	if tp != Vector3.INF:
		var pm := mesh.mesh as PlaneMesh
		if pm != null:
			var local := mesh.to_local(tp)
			if absf(local.x) <= pm.size.x * 0.5 and absf(local.z) <= pm.size.y * 0.5:
				index = _row_from_local(local)
	_list.set_hover_row(index)
	if index >= 0:
		# The row pop animates, so the board texture must keep re-rendering.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# ---------------- Hover ----------------

func _on_mouse_entered() -> void:
	if not _revealed or _proceeding or _badge_held:
		return
	_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_tween_hover(HOVER_SCALE)


func _on_mouse_exited() -> void:
	if not _hovered:
		return
	_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_tween_hover(1.0)


func _tween_hover(target: float) -> void:
	if _hover_tw:
		_hover_tw.kill()
	_hover_tw = create_tween()
	_hover_tw.tween_property(mesh, "scale", Vector3.ONE * target, HOVER_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------- Row clicks ----------------

func _on_input_event(_cam: Camera3D, event: InputEvent, pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var index := _row_at(pos)
	if index < 0:
		return  # clicked the paper outside every surgery row — no day chosen
	_proceeding = true
	_list.set_hover_row(-1)
	_list.highlight_row(index)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	proceed.emit(index, _list.get_entry(index))


func _row_at(pos: Vector3) -> int:
	# World hit point → row index (click handler entry point).
	return _row_from_local(mesh.to_local(pos))


func _row_from_local(local: Vector3) -> int:
	# Paper-local plane coords → viewport pixels → row index. PlaneMesh lies
	# in XZ, flat on the table: local x = paper width, local z = paper height
	# (the v axis). UV (0,0) is at (-w/2, -h/2), so v grows toward +z.
	var pm := mesh.mesh as PlaneMesh
	if pm == null or pm.size.x <= 0.0 or pm.size.y <= 0.0:
		return -1
	var u := clampf(local.x / pm.size.x + 0.5, 0.0, 1.0)
	var v := clampf(local.z / pm.size.y + 0.5, 0.0, 1.0)
	return _list.row_at(Vector2(u * VIEW_SIZE.x, v * VIEW_SIZE.y))


# ---------------- List rendering ----------------

func _build_list() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	_list = SURGERY_LIST.instantiate()
	_viewport.add_child(_list)

	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_texture = _viewport.get_texture()
	_mat.render_priority = 1
	mesh.material_override = _mat
