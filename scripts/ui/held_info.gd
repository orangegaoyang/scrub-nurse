extends Control
## Held-instrument info: shows a one-line description at the bottom of the
## screen while the player holds an instrument (mirrors the voice line).

@onready var sentence: Label = $Panel/Sentence


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	GameState.held_changed.connect(_on_held_changed)


func _on_held_changed(inst) -> void:
	if inst == null:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): visible = false)
	else:
		sentence.text = "这是%s，%s。" % [inst.def.name_cn, inst.def.purpose]
		visible = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
