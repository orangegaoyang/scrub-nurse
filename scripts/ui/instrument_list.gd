extends Control
## Instrument list paper, shown in the upper-left of the screen during prep.
## Instruments are scattered on the back table; the list shows each one's
## destination — Mayo slot (sequence order, slot_index < 6) or back-table
## category zone (slot_index >= 6) — plus usage counts, checking off each
## placement.

const COLOR_DONE := Color(0.45, 0.62, 0.45)
const COLOR_TODO := Color(1, 1, 1)

const CATEGORY_CN := {
	"cutting": "切割",
	"clamping": "钳夹",
	"grasping": "抓持",
	"suturing": "缝合",
	"dressing": "敷料",
}

@onready var title_label: Label = $Panel/TitleLabel
@onready var count_label: Label = $Panel/CountLabel
@onready var items_box: VBoxContainer = $Panel/Scroll/ItemsBox

var _item_labels: Dictionary = {}  # instrument_id -> Label
var _placed: Dictionary = {}  # instrument_id -> true


func _ready() -> void:
	_build_list()
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.prep_item_secured.connect(_on_secured)
	GameState.prep_back_item_secured.connect(_on_secured)
	visible = false


func _build_list() -> void:
	for child in items_box.get_children():
		child.queue_free()
	_item_labels.clear()
	_placed.clear()
	var has_back_instruments: bool = false
	for id in ProcedureData.instrument_order:
		if ProcedureData.get_instrument(id).slot_index >= 6:
			has_back_instruments = true
	title_label.text = "器械清单:6 件摆上 Mayo,其余归位器械台" if has_back_instruments \
		else "器械清单:摆上 Mayo(按序号)"
	var i: int = 1
	for id in ProcedureData.instrument_order:
		var def = ProcedureData.get_instrument(id)
		var lbl := Label.new()
		if def.slot_index >= 6:
			lbl.text = "%d. %s — %s(器械台 · %s)" % [
				i, def.name_cn, def.purpose, CATEGORY_CN.get(def.category, def.category)
			]
		elif def.uses > 1:
			lbl.text = "%d. %s — %s(×%d)" % [i, def.name_cn, def.purpose, def.uses]
		else:
			lbl.text = "%d. %s — %s" % [i, def.name_cn, def.purpose]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", COLOR_TODO)
		items_box.add_child(lbl)
		_item_labels[id] = lbl
		i += 1
	_update_count()


func _on_secured(instrument_id: String) -> void:
	if not _item_labels.has(instrument_id) or _placed.get(instrument_id, false):
		return
	_placed[instrument_id] = true
	var lbl: Label = _item_labels[instrument_id]
	lbl.text = "✓ " + lbl.text
	lbl.add_theme_color_override("font_color", COLOR_DONE)
	_update_count()


func _update_count() -> void:
	count_label.text = "已放好 %d / %d" % [_placed.size(), ProcedureData.instrument_order.size()]


func _on_phase_changed(new_phase: int) -> void:
	# The instrument list paper appears only once prep is done and the
	# surgery is underway — during prep the player is guided by the slot
	# highlights and the held-instrument speech bubble instead.
	visible = (new_phase == GameState.Phase.SURGERY)
