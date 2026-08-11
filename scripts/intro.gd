extends Node3D
## Intro:
## Day 1: physics-drop badge → click to pick up (lifts toward camera), mouse
##   follows on the table plane, click to drop → snap into slot if horizontally
##   close, else free-fall back onto the table → wait 1s → physics-drop schedule
##   → click schedule → proceed to corridor.
## Replay (same session): badge already in slot, wait 1s, throw schedule.
##
## Badge pick-up/drag/drop/snap lives on the BadgeProp node itself
## (scripts/intro_badge.gd); this script drives the scene flow and the shared
## throw physics used by both badge and schedule.

const SCHEDULE_DELAY := 1.0
const REST_Y := 1.3 # table top (1.2) + half collision-box height (0.1)
const THROW_TIMEOUT := 3.0
const SCHEDULE_LAND := Vector3(-0.05, 0.0, 0.05) # lower half of the table, clear of the slot
const SCHEDULE_BOARD := Vector2(0.369, 0.45)
const SCHEDULE_ROWS := 3
const SCHEDULE_COLS := 2
const SCHEDULE_CELL_MARGIN := 0.03
const SCHEDULE_CELL_LABELS := ["手术 1", "手术 2", "手术 3", "手术 4", "手术 5", "手术 6"]

# Persists across scene reloads within one process: skip the badge throw on
# replays (badge stays in slot).
static var _intro_seen_once := false

@onready var camera: Camera3D = $Camera3D
@onready var badge: IntroBadge = $BadgeProp
@onready var schedule: RigidBody3D = $ScheduleProp
@onready var slot: MeshInstance3D = $BadgeSlot
@onready var voice: AudioStreamPlayer = $Voice

var _proceeding: bool = false


func _ready() -> void:
	#camera.look_at(Vector3(0.0, 1.45, 0.0))
	badge.visible = false
	schedule.visible = false
	slot.visible = false
	badge.setup(camera, slot)
	_build_schedule_cells()
	schedule.freeze = true
	schedule.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	await Transition.fade_in()
	if _intro_seen_once:
		await _replay_loop()
	else:
		await _first_loop()


# ---------------- Loops ----------------

func _first_loop() -> void:
	badge.visible = true
	badge.freeze = false
	_intro_seen_once = true
	_voice("intro_badge")
	badge.start_hint()
	await badge.placed
	await _wait(SCHEDULE_DELAY)
	_throw_schedule()


func _replay_loop() -> void:
	# Badge already in slot; just wait, then throw schedule.
	badge.place_in_slot()
	await _wait(1.0)
	_throw_schedule()


func _throw_schedule() -> void:
	schedule.visible = true
	schedule.freeze = false
	_voice("intro_schedule")


# ---------------- Schedule ----------------

func _build_schedule_cells() -> void:
	# 3x2 grid of clickable cells laid out on the schedule board (its children,
	# so they ride along the throw). Collision boxes poke above the board's
	# physics box so the pick ray hits the cell, not the board.
	var font := load("res://assets/fonts/ArialUnicode.ttf") as Font
	var cell_w := (SCHEDULE_BOARD.x - SCHEDULE_CELL_MARGIN * (SCHEDULE_COLS + 1)) / SCHEDULE_COLS
	var cell_d := (SCHEDULE_BOARD.y - SCHEDULE_CELL_MARGIN * (SCHEDULE_ROWS + 1)) / SCHEDULE_ROWS
	var x0 := -SCHEDULE_BOARD.x * 0.5 + SCHEDULE_CELL_MARGIN + cell_w * 0.5
	var z0 := -SCHEDULE_BOARD.y * 0.5 + SCHEDULE_CELL_MARGIN + cell_d * 0.5
	for row in range(SCHEDULE_ROWS):
		for col in range(SCHEDULE_COLS):
			var idx := row * SCHEDULE_COLS + col
			var cell := Area3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(cell_w, 0.2, cell_d)
			cs.position = Vector3(0, 0.1, 0)
			cs.shape = box
			cell.add_child(cs)
			var lbl := Label3D.new()
			lbl.text = SCHEDULE_CELL_LABELS[idx]
			lbl.position = Vector3(0, 0.01, 0)
			lbl.rotation_degrees = Vector3(-90, 0, 0)
			lbl.font_size = 32
			lbl.pixel_size = 0.001
			lbl.modulate = Color(0.2, 0.2, 0.2)
			if font:
				lbl.font = font
			cell.add_child(lbl)
			cell.position = Vector3(
				x0 + col * (cell_w + SCHEDULE_CELL_MARGIN),
				0.0,
				z0 + row * (cell_d + SCHEDULE_CELL_MARGIN))
			cell.input_event.connect(_on_schedule_input_event)
			schedule.add_child(cell)


func _on_schedule_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding or not schedule.freeze:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceeding = true
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


func _voice(key: String) -> void:
	var path := "res://assets/audio/%s.wav" % key
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		voice.stream = s
		voice.play()

func _on_table_area_3d_body_entered(body: Node3D) -> void:
	if body ==badge:
		badge.freeze = true
	if body == schedule:
		schedule.freeze = true
