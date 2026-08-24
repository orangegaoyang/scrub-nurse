extends Control
## Demand bubble: a speech bubble near the surgeon's hand (top-right, below the
## top bar) showing what the surgeon currently wants — instrument name plus the
## use counter for reusable instruments ("纱布 2/3").

@onready var label: Label = $Panel/Label


func _ready() -> void:
	visible = false
	var surgeon := get_node_or_null("/root/Main/Surgeon")
	if surgeon:
		surgeon.demand_changed.connect(_on_demand)
		surgeon.hand_retracted.connect(_on_retracted)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_demand(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def == null:
		return
	var u: Dictionary = ProcedureData.usage_at(GameState.current_demand_index)
	if not u.is_empty() and u["id"] == id and def.uses > 1:
		label.text = "%s %d/%d" % [def.name_cn, u["usage"], u["total"]]
	else:
		label.text = def.name_cn
	visible = true


func _on_retracted() -> void:
	visible = false


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != GameState.Phase.SURGERY:
		visible = false
