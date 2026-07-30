extends Control
## Intro / title page. Start button loads the surgery scene.

@onready var start_btn: TextureButton = $StartBtn


func _ready() -> void:
	start_btn.pressed.connect(_on_start)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
