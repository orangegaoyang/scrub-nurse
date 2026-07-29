extends Control
## HUD: demand/take-back prompt at the bottom, score (correct/wrong) top-right.

@onready var demand_label: Label = $DemandPanel/DemandLabel
@onready var score_label: Label = $ScoreLabel


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.score_updated.connect(_update_score)
	var surgeon: Node = get_node_or_null("/root/Main/Surgeon")
	if surgeon:
		surgeon.demand_changed.connect(_on_demand_changed)
		surgeon.returning_instrument.connect(_on_returning)
		surgeon.hand_retracted.connect(_clear_demand)
	_update_score()


func _on_phase_changed(new_phase: int) -> void:
	visible = (new_phase == GameState.Phase.SURGERY)
	if visible:
		_clear_demand()


func _on_demand_changed(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		demand_label.text = "递送:%s" % def.name_cn


func _on_returning(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		demand_label.text = "取回:%s" % def.name_cn


func _clear_demand() -> void:
	demand_label.text = ""


func _update_score() -> void:
	score_label.text = "正确 %d  错误 %d" % [GameState.surgery_correct, GameState.surgery_wrong]
