extends Control
## HUD: shows current demand, score, timer during surgery.

@onready var demand_label: Label = $Panel/DemandLabel
@onready var score_label: Label = $Panel/ScoreLabel
@onready var timer_label: Label = $Panel/TimerLabel


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.score_updated.connect(_update_score)
	_update_score()


func _process(_delta: float) -> void:
	if GameState.current_phase == GameState.Phase.SURGERY:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - GameState.surgery_start_time
		timer_label.text = "时间: %.1f s" % elapsed


func _on_phase_changed(new_phase: int) -> void:
	visible = (new_phase == GameState.Phase.SURGERY)
	if new_phase == GameState.Phase.SURGERY:
		_update_demand()


func update_demand() -> void:
	_update_demand()


func _update_demand() -> void:
	if GameState.current_demand_index >= ProcedureData.demand_sequence.size():
		demand_label.text = "完成!"
		return
	var id: String = ProcedureData.get_demand_at(GameState.current_demand_index)
	var def = ProcedureData.get_instrument(id)
	if def:
		demand_label.text = "递送:%s" % def.name_cn


func _update_score() -> void:
	score_label.text = "正确 %d  错误 %d" % [GameState.surgery_correct, GameState.surgery_wrong]
	_update_demand()
