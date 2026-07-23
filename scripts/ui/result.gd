extends Control
## Result screen: stars, time, accuracy, restart.

@onready var stars_label: Label = $Panel/StarsLabel
@onready var stats_label: Label = $Panel/StatsLabel
@onready var restart_button: Button = $Panel/RestartButton


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	restart_button.pressed.connect(_on_restart)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.RESULT:
		visible = true
		_show_result()
	else:
		visible = false


func _show_result() -> void:
	var stars: int = GameState.get_stars()
	stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	var total: int = GameState.surgery_correct + GameState.surgery_wrong
	var acc: float = (float(GameState.surgery_correct) / float(total) * 100.0) if total > 0 else 0.0
	stats_label.text = "正确:%d  错误:%d  准确率:%.0f%%  用时:%.1f s" % [
		GameState.surgery_correct, GameState.surgery_wrong, acc, GameState.surgery_elapsed
	]


func _on_restart() -> void:
	get_tree().reload_current_scene()
