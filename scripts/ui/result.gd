extends Control
## Result screen: a ceremonial reveal — dim the world, raise the result card,
## pop the stars one-by-one (gold for earned, dim for missed), then the grade,
## the stats, and finally the restart button. Each step cascades so it feels
## like a staged finale rather than a wall of text appearing at once.

const GOLD := Color(1.0, 0.78, 0.22)
const GREY := Color(0.55, 0.55, 0.55, 0.45)
const DIM_ALPHA := 0.6

@onready var dim: ColorRect = $Dim
@onready var card: Panel = $Card
@onready var title: Label = $Card/TitleLabel
@onready var stars_box: HBoxContainer = $Card/StarsBox
@onready var grade: Label = $Card/GradeLabel
@onready var stats: Label = $Card/StatsLabel
@onready var progress: Label = $Card/ProgressLabel
@onready var restart_button: Button = $Card/RestartButton

var _stars: Array = []


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	restart_button.pressed.connect(_on_restart)
	_stars = [stars_box.get_node("Star0"), stars_box.get_node("Star1"), stars_box.get_node("Star2")]


func _on_phase_changed(_new_phase: int) -> void:
	# Read the authoritative phase instead of the event's: a finish can be
	# triggered synchronously inside the TIDY emission, so this handler may
	# run again with TIDY after the nested RESULT already showed the card.
	var phase: int = GameState.current_phase
	if phase == GameState.Phase.RESULT:
		if not visible:
			visible = true
			_show_result()
	else:
		visible = false


func _show_result() -> void:
	var star_count: int = GameState.get_stars()
	grade.text = _grade_text(star_count)
	var total: int = GameState.surgery_correct + GameState.surgery_wrong
	var acc: float = (float(GameState.surgery_correct) / float(total) * 100.0) if total > 0 else 0.0
	stats.text = "正确 %d    错误 %d    准确率 %.0f%%    用时 %.1f s" % [
		GameState.surgery_correct, GameState.surgery_wrong, acc, GameState.surgery_elapsed
	]
	var proc_id: String = GameState.current_procedure_id()
	progress.text = "本台 +%d★  ·  全局 %d★(Level %s)  ·  本术式 %d★(Level %s)" % [
		GameState.last_stars,
		PlayerProfile.total_stars, _level_roman(PlayerProfile.global_level()),
		PlayerProfile.procedure_stars(proc_id), _level_roman(PlayerProfile.procedure_level(proc_id)),
	]
	# Reset everything for the entrance.
	dim.color.a = 0.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.86, 0.86)
	card.modulate.a = 0.0
	title.modulate.a = 0.0
	grade.modulate.a = 0.0
	stats.modulate.a = 0.0
	progress.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	restart_button.disabled = true
	for s in _stars:
		s.pivot_offset = s.size / 2.0
		s.scale = Vector2.ZERO
	# Staged reveal sequence.
	Sfx.play("result_reveal")
	var tw := create_tween()
	tw.tween_property(dim, "color:a", DIM_ALPHA, 0.4)
	tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "modulate:a", 1.0, 0.3)
	for i in range(_stars.size()):
		var s: Label = _stars[i]
		s.modulate = GOLD if i < star_count else GREY
		if i < star_count:
			tw.tween_property(s, "scale", Vector2(1.25, 1.25), 0.18).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", Vector2.ONE, 0.16)
			tw.tween_callback(func() -> void: Sfx.play("star_pop"))
		else:
			tw.tween_property(s, "scale", Vector2.ONE, 0.3)
	tw.tween_property(grade, "modulate:a", 1.0, 0.3)
	tw.tween_property(stats, "modulate:a", 1.0, 0.3)
	tw.tween_property(progress, "modulate:a", 1.0, 0.3)
	tw.tween_property(restart_button, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func(): restart_button.disabled = false)


func _level_roman(level: int) -> String:
	match level:
		3:
			return "III"
		2:
			return "II"
		_:
			return "I"


func _grade_text(star_count: int) -> String:
	match star_count:
		3:
			return "完美演出"
		2:
			return "表现出色"
		1:
			return "顺利完成"
		_:
			return "继续努力"


func _on_restart() -> void:
	# Settlement done — back to the schedule board to pick the next surgery.
	Transition.fade_out(0.5)
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
