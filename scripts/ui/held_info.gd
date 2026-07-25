extends Control
## Held-instrument info card: shows name + purpose while the player holds an
## instrument, with a quick fade in/out.

@onready var name_label: Label = $Panel/NameLabel
@onready var purpose_label: Label = $Panel/PurposeLabel


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
		name_label.text = inst.def.name_cn
		purpose_label.text = inst.def.purpose
		visible = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
