extends Control
## Countdown: shows 3-2-1 then signals surgery to start.

signal finished()

@onready var label: Label = $Label


func _ready() -> void:
	label.visible = false


func run() -> void:
	label.visible = true
	for n in ["3", "2", "1", "开始!"]:
		label.text = n
		label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.1)
		await Util.wait(1.0)
	label.visible = false
	finished.emit()
