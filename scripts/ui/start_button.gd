extends Control
## "Setup complete, start surgery" button. Shown when prep finishes (COUNTDOWN
## phase is reused as the "ready, awaiting start" state). No 3-2-1 countdown.

@onready var button: Button = $Button


func _ready() -> void:
	visible = false
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: int) -> void:
	visible = (new_phase == GameState.Phase.COUNTDOWN)


func _on_button_pressed() -> void:
	GameState.start_surgery()
