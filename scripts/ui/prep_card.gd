extends Control
## Prep card: shows the expected instrument layout/order (teaching aid).

@onready var vbox: VBoxContainer = $Panel/VBoxContainer


func _ready() -> void:
	_populate()


func _populate() -> void:
	for c in vbox.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "器械摆放规范"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	var seq: Array = ProcedureData.demand_sequence
	for i in range(seq.size()):
		var def = ProcedureData.get_instrument(seq[i])
		var lbl := Label.new()
		lbl.text = "%d. %s — %s" % [i + 1, def.name_cn, def.purpose]
		lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(lbl)
