extends Control
## 2D "准备完毕" checklist overlay, shown on entering the COUNTDOWN phase.
## Replaces the old in-world 3D board and the plain StartButton.
##
## All static config lives in the .tscn: the card.png frame, the title/subtitle/
## hint labels (fonts + colours), the start_surgery.png button, and the reusable
## row template (checklist_row.tscn). This script only fills in the data and
## drives the presentation — one row per instrument in
## ProcedureData.instrument_order (number badge + 名称 + green ✓, no icons),
## items fade in one-by-one and get checked, then the button fades in. Pressing
## the button hands off to the surgery scene (main.tscn for now).

signal list_presented()

const MAIN_SCENE := "res://scenes/surgery.tscn"   # surgical hand-off target
const ROW_SCENE: PackedScene = preload("res://scenes/ui/checklist_row.tscn")

@onready var rows_box: VBoxContainer = $Card/Content/RowsBox
@onready var title_label: Label = $Card/Title
@onready var start_button: TextureButton = $Card/Content/StartButton

var _rows: Array = []   # instantiated row scene per instrument, for the cascade
var _revealed := false


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # hidden until revealed
	visible = false


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.COUNTDOWN:
		_present()
	else:
		visible = false


func _present() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	_build_rows()
	# Actors start at alpha 0 (set in the .tscn); re-zero here to be explicit.
	title_label.modulate.a = 0.0
	start_button.modulate.a = 0.0
	start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.3)
	for row in _rows:
		tw.tween_interval(0.12)
		tw.tween_property(row, "modulate:a", 1.0, 0.2)
		tw.tween_callback(_check_row.bind(row))
	tw.tween_interval(0.25)
	tw.tween_callback(_reveal_button)
	tw.tween_property(start_button, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): list_presented.emit())


func _reveal_button() -> void:
	start_button.mouse_filter = Control.MOUSE_FILTER_STOP  # clickable now
	Sfx.play("badge_land")


func _check_row(row: Control) -> void:
	# Reveal the green ✓ circle (the .tscn bakes it hidden + the name colour);
	# the name text stays in its configured colour.
	var check: Control = row.get_node("Check")
	check.modulate.a = 1.0
	Sfx.play("badge_snap")


func _build_rows() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	_rows.clear()
	var order := ProcedureData.instrument_order
	for i in order.size():
		var def = ProcedureData.get_instrument(order[i])
		var row: Control = ROW_SCENE.instantiate()
		row.get_node("Badge/BadgeLabel").text = str(i + 1)
		row.get_node("Name").text = def.name_en
		rows_box.add_child(row)
		_rows.append(row)


func _on_start_pressed() -> void:
	# Flag the surgery scene to start in SURGERY (seat instruments, reveal the
	# surgeon) instead of replaying prep, then white-flash hand off.
	GameState.enter_surgery_direct = true
	Sfx.play("surgery_start")
	await Transition.flash_white(0.25)
	get_tree().change_scene_to_file(MAIN_SCENE)
