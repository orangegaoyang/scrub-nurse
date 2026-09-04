extends Control
## HUD: bottom hint bar (return/tidy hints), score top-right, neutral-zone
## capacity top-left (with a pop when the tray first fills), tidy panel
## during the final clear-up, and the one-time "back table is behind you
## (Q)" hint after the push transition.

const Q_HINT_DELAY := 2.6  # after the player acknowledges the intro hint

@onready var demand_panel: Panel = $DemandPanel
@onready var demand_label: Label = $DemandPanel/DemandLabel
@onready var zone_hint: Panel = $ZoneHint
@onready var zone_hint_label: Label = $ZoneHint/Label
@onready var zone_got_it_button: Button = $ZoneHint/GotItButton
@onready var score_label: Label = $ScoreLabel
@onready var capacity_label: Label = $CapacityLabel
@onready var q_hint: Label = $QHint
@onready var tidy_panel: Panel = $TidyPanel
@onready var tidy_label: Label = $TidyPanel/TidyLabel
@onready var skip_button: Button = $TidyPanel/SkipButton
@onready var beat_dots: HBoxContainer = $BeatDots

# 四拍指示:弱拍暗白,第 4 拍(呼叫拍)暖红;被击中时点亮回弹。
const DOT_DIM := Color(1, 1, 1, 0.22)
const DOT_DIM_CALL := Color(1, 0.5, 0.4, 0.4)
const DOT_LIT := Color(1, 1, 1, 0.95)
const DOT_LIT_CALL := Color(1, 0.45, 0.3, 1.0)

var _last_zone_count: int = 0
var _q_hint_pending: bool = false
var _dots: Array[Label] = []


func _ready() -> void:
	visible = false
	demand_panel.visible = false
	zone_hint.visible = false
	tidy_panel.visible = false
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.score_updated.connect(_update_score)
	GameState.hint_changed.connect(_on_hint)
	GameState.tidy_progress_changed.connect(_on_tidy_progress)
	GameState.view_switched.connect(_on_view_switched)
	GameState.surgeon_line_start.connect(_on_surgeon_line_start)
	skip_button.pressed.connect(_on_skip)
	zone_got_it_button.pressed.connect(_on_got_it)
	for c in beat_dots.get_children():
		var l := c as Label
		if l != null:
			l.modulate = DOT_DIM
			_dots.append(l)
	Conductor.beat.connect(_on_conductor_beat)
	_update_score()


func _process(_delta: float) -> void:
	if not visible:
		return
	var zone: Node = get_node_or_null("/root/Main/NeutralZone")
	if zone != null:
		capacity_label.text = "中立区 %d/%d" % [zone.count(), zone.capacity]
		if zone.count() > _last_zone_count:
			_pop_capacity()
		_last_zone_count = zone.count()
		if zone_hint.visible:
			_follow_zone(zone)


func _follow_zone(zone: Node) -> void:
	## Keep the intro hint floating above the neutral-zone tray on screen.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var p: Vector2 = cam.unproject_position(zone.global_position + Vector3(0, 0.06, 0))
	zone_hint.position = Vector2(p.x - zone_hint.size.x * 0.5, p.y - zone_hint.size.y - 30)


func _pop_capacity() -> void:
	## Draw the eye to the counter when the tray first fills (1/3).
	capacity_label.pivot_offset = capacity_label.size * 0.5
	capacity_label.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(capacity_label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_phase_changed(_new_phase: int) -> void:
	# Read the authoritative phase instead of the event's: a finish can be
	# triggered synchronously inside the TIDY emission (S1/S2 gauze toss
	# endings, S3 auto-finish), so by the time this handler runs the phase
	# may already be RESULT — the HUD must not re-show over the result card.
	var phase: int = GameState.current_phase
	visible = (phase == GameState.Phase.SURGERY or phase == GameState.Phase.TIDY)
	tidy_panel.visible = (phase == GameState.Phase.TIDY)
	beat_dots.visible = (phase == GameState.Phase.SURGERY)
	if phase == GameState.Phase.SURGERY:
		_reset_dots()
	if phase == GameState.Phase.SURGERY:
		demand_panel.visible = false
		zone_hint.visible = false
		_last_zone_count = -1  # first deposit (0 -> 1) pops the counter
		q_hint.visible = false
	elif phase == GameState.Phase.TIDY:
		_on_tidy_progress(GameState.back_table_count)


func _on_surgeon_line_start() -> void:
	# The player acknowledged the intro hint — start the Q-hint clock.
	# (Only procedures with a back table behind the player need the Q hint.)
	if ProcedureData.has_back_table() and not _q_hint_pending:
		_q_hint_pending = true
		_show_q_hint_later()


func _show_q_hint_later() -> void:
	## One-time per run: after the transition settles, point at the Q key.
	await Util.wait(Q_HINT_DELAY)
	if GameState.current_phase == GameState.Phase.SURGERY:
		q_hint.visible = true


func _on_view_switched() -> void:
	# The player found the Q key — retire the hint for good.
	if q_hint.visible:
		q_hint.visible = false
	_q_hint_pending = false


func _on_hint(text: String, ack: bool = false) -> void:
	if ack:
		# Intro hint: floats above the neutral-zone tray, fading in with it.
		# Size the panel to the text so the button never overlaps it.
		demand_panel.visible = false
		zone_hint_label.text = text
		var font_size: int = zone_hint_label.get_theme_font_size("font_size")
		var text_w: float = font_size * text.length() * 1.05 + 24.0
		zone_hint.size = Vector2(text_w + 124.0, 60.0)
		zone_hint.visible = true
		zone_hint.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(zone_hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		zone_hint.visible = false
		demand_label.text = text
		# The tidy panel owns the bottom of the screen in TIDY; the hint bar
		# only shows during surgery.
		demand_panel.visible = text != "" and GameState.current_phase == GameState.Phase.SURGERY


func _on_got_it() -> void:
	zone_hint.visible = false
	GameState.hint_changed.emit("", false)
	GameState.surgeon_line_start.emit()


func _on_tidy_progress(count: int) -> void:
	if ProcedureData.has_back_table():
		tidy_label.text = "收尾清扫:归位 back table  %d / %d" % [
			count, ProcedureData.total_instances()
		]
	else:
		tidy_label.text = "收尾清扫:清空中立区,器械归位 Mayo"


func _on_skip() -> void:
	GameState.finish_surgery(true)


func _update_score() -> void:
	score_label.text = "正确 %d  错误 %d" % [GameState.surgery_correct, GameState.surgery_wrong]


func _on_conductor_beat(global_beat: int) -> void:
	## 四拍脉冲:每一拍点亮对应圆点,第 4 拍(呼叫拍)红色强调。
	if not visible or GameState.current_phase != GameState.Phase.SURGERY:
		return
	var i := global_beat % Conductor.BEATS_PER_BAR
	if i >= _dots.size():
		return
	var l := _dots[i]
	var lit := DOT_LIT_CALL if i == Conductor.CALL_BEAT else DOT_LIT
	var dim := DOT_DIM_CALL if i == Conductor.CALL_BEAT else DOT_DIM
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.45, 1.45)
	l.modulate = lit
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "modulate", dim, 0.35)


func _reset_dots() -> void:
	for i in _dots.size():
		_dots[i].modulate = DOT_DIM_CALL if i == Conductor.CALL_BEAT else DOT_DIM
		_dots[i].scale = Vector2.ONE
