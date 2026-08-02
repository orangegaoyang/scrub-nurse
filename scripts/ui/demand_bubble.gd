extends Control
## Demand bubble: a speech bubble near the surgeon's hand (top-right, below the
## top bar) showing what the surgeon currently wants — the instrument name when
## demanding, or a take-back hint when returning a used instrument. Mirrors the
## surgeon's demand_changed / returning_instrument / hand_retracted signals.

@onready var label: Label = $Panel/Label


func _ready() -> void:
	visible = false
	var surgeon := get_node_or_null("/root/Main/Surgeon")
	if surgeon:
		surgeon.demand_changed.connect(_on_demand)
		surgeon.returning_instrument.connect(_on_returning)
		surgeon.hand_retracted.connect(_on_retracted)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_demand(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		label.text = def.name_cn
		visible = true


func _on_returning(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		label.text = "取回 " + def.name_cn
		visible = true


func _on_retracted() -> void:
	visible = false


func _on_phase_changed(new_phase: int) -> void:
	if new_phase != GameState.Phase.SURGERY:
		visible = false
