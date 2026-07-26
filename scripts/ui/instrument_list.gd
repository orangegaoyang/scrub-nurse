extends Control
## Instrument list paper, shown in the upper-left of the screen after the pack
## is opened. Replaces the flat Label3D that lay on the tray.
## Each line gets checked off as the instrument is placed correctly.

const COLOR_DONE := Color(0.45, 0.62, 0.45)
const COLOR_TODO := Color(1, 1, 1)

@onready var count_label: Label = $Panel/CountLabel
@onready var items_box: VBoxContainer = $Panel/Scroll/ItemsBox

var _item_labels: Dictionary = {}  # instrument_id -> Label
var _placed_count: int = 0


func _ready() -> void:
	_build_list()
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.prep_item_secured.connect(_on_prep_item_secured)
	visible = true


func _build_list() -> void:
	for child in items_box.get_children():
		child.queue_free()
	_item_labels.clear()
	_placed_count = 0
	var i: int = 1
	for id in ProcedureData.demand_sequence:
		var def = ProcedureData.get_instrument(id)
		var lbl := Label.new()
		lbl.text = "%d. %s — %s" % [i, def.name_cn, def.purpose]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", COLOR_TODO)
		items_box.add_child(lbl)
		_item_labels[id] = lbl
		i += 1
	_update_count()


func _on_prep_item_secured(instrument_id: String) -> void:
	if not _item_labels.has(instrument_id):
		return
	var lbl: Label = _item_labels[instrument_id]
	# avoid double-count if somehow emitted twice
	if not lbl.text.begins_with("✓"):
		_placed_count += 1
	lbl.text = "✓ " + lbl.text
	lbl.add_theme_color_override("font_color", COLOR_DONE)
	_update_count()


func _update_count() -> void:
	count_label.text = "已放好 %d / %d" % [_placed_count, ProcedureData.demand_sequence.size()]


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.RESULT:
		visible = false
