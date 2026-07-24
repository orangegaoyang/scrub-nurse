extends Control
## HUD: shows current demand (on hand extend), take-back prompt, score, timer.

@onready var demand_label: Label = $Panel/DemandLabel
@onready var score_label: Label = $Panel/ScoreLabel
@onready var timer_label: Label = $Panel/TimerLabel


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.score_updated.connect(_update_score)
	var surgeon: Node = get_node("/root/Main/Surgeon")
	surgeon.demand_changed.connect(_on_demand_changed)
	surgeon.returning_instrument.connect(_on_returning)
	_update_score()


func _process(_delta: float) -> void:
	if GameState.current_phase == GameState.Phase.SURGERY:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - GameState.surgery_start_time
		timer_label.text = "时间: %.1f s" % elapsed


func _on_phase_changed(new_phase: int) -> void:
	visible = (new_phase == GameState.Phase.SURGERY)


func _on_demand_changed(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		demand_label.text = "递送:%s" % def.name_cn


func _on_returning(id: String) -> void:
	var def = ProcedureData.get_instrument(id)
	if def:
		demand_label.text = "取回:%s" % def.name_cn


func _update_score() -> void:
	score_label.text = "正确 %d  错误 %d" % [GameState.surgery_correct, GameState.surgery_wrong]
