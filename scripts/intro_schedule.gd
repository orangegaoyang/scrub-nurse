class_name IntroSchedule
extends RigidBody3D
## The "today's surgery" board in the intro scene. Builds its own 3x2 grid of
## clickable surgery cells on top of the board. Call reveal() to drop it onto
## the table; emits `proceed` when the player clicks any cell — the intro scene
## owns the actual transition to the corridor.

signal proceed

const ROWS := 3
const COLS := 2
const CELL_MARGIN := 0.03
const CELL_LABELS := ["手术 1", "手术 2", "手术 3", "手术 4", "手术 5", "手术 6"]
const VOICE_KEY := "intro_schedule"

@onready var mesh: MeshInstance3D = $Mesh

var _proceeding: bool = false
var _voice: AudioStreamPlayer


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	visible = false
	_build_cells()


func setup(voice: AudioStreamPlayer) -> void:
	_voice = voice


func reveal() -> void:
	# Drop onto the table; the Intro scene's Table Area3D freezes us on contact.
	visible = true
	freeze = false
	# Voice line plays on every reveal (first loop and replay).
	Util.play_voice(_voice, VOICE_KEY)


# ---------------- Cells ----------------

func _build_cells() -> void:
	# 3x2 grid of clickable cells laid out on the board (children, so they
	# ride along the drop). Collision boxes poke above the board's physics box
	# so the pick ray hits the cell, not the board.
	var board_size := (mesh.mesh as PlaneMesh).size
	var font := load("res://assets/fonts/ArialUnicode.ttf") as Font
	var cell_w := (board_size.x - CELL_MARGIN * (COLS + 1)) / COLS
	var cell_d := (board_size.y - CELL_MARGIN * (ROWS + 1)) / ROWS
	var x0 := -board_size.x * 0.5 + CELL_MARGIN + cell_w * 0.5
	var z0 := -board_size.y * 0.5 + CELL_MARGIN + cell_d * 0.5
	for row in range(ROWS):
		for col in range(COLS):
			var idx := row * COLS + col
			var cell := Area3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(cell_w, 0.2, cell_d)
			cs.position = Vector3(0, 0.1, 0)
			cs.shape = box
			cell.add_child(cs)
			var lbl := Label3D.new()
			lbl.text = CELL_LABELS[idx]
			lbl.position = Vector3(0, 0.01, 0)
			lbl.rotation_degrees = Vector3(-90, 0, 0)
			lbl.font_size = 32
			lbl.pixel_size = 0.001
			lbl.modulate = Color(0.2, 0.2, 0.2)
			# The paper uses a transparent material, so its transparent pass can
			# otherwise draw over Label3D. Keep the text on top of the paper.
			lbl.no_depth_test = true
			lbl.render_priority = 2
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if font:
				lbl.font = font
			cell.add_child(lbl)
			cell.position = Vector3(
				x0 + col * (cell_w + CELL_MARGIN),
				0.0,
				z0 + row * (cell_d + CELL_MARGIN))
			cell.input_event.connect(_on_cell_input_event)
			add_child(cell)


func _on_cell_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _n: Vector3, _idx: int) -> void:
	if _proceeding or not freeze:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceeding = true
		proceed.emit()
