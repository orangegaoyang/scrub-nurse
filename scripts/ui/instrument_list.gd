extends Control
## Instrument list paper, shown in the upper-left of the screen after the pack
## is opened. Replaces the flat Label3D that lay on the tray.

@onready var title_label: Label = $Panel/TitleLabel
@onready var items_label: Label = $Panel/ItemsLabel


func _ready() -> void:
	visible = false
	_build_list()
	var pack: Node = get_node_or_null("/root/Main/MayoStand/Pack")
	if pack:
		pack.opened.connect(_on_pack_opened)


func _build_list() -> void:
	var lines: Array[String] = []
	for i in range(ProcedureData.demand_sequence.size()):
		var def = ProcedureData.get_instrument(ProcedureData.demand_sequence[i])
		lines.append("%d. %s — %s" % [i + 1, def.name_cn, def.purpose])
	items_label.text = "\n".join(lines)


func _on_pack_opened() -> void:
	visible = true
