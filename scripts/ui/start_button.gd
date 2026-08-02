extends Control
## "进入手术" button. Revealed at the END of the prep-complete board's checklist
## cascade (its list_presented signal), not on entering COUNTDOWN, so the flow
## reads: board → checklist fills in one-by-one → button appears. Pressing it
## starts surgery.

@onready var button: Button = $Button


func _ready() -> void:
	visible = false
	button.modulate.a = 0.0
	GameState.phase_changed.connect(_on_phase_changed)
	var board := get_node_or_null("/root/Main/PrepComplete")
	if board:
		board.list_presented.connect(_reveal)


func _on_phase_changed(new_phase: int) -> void:
	# Stay hidden until the board finishes its cascade and calls _reveal().
	if new_phase != GameState.Phase.COUNTDOWN:
		visible = false


func _reveal() -> void:
	visible = true
	button.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(button, "modulate:a", 1.0, 0.4)


func _on_button_pressed() -> void:
	GameState.start_surgery()
