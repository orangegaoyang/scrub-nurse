class_name Pack
extends Node3D
## Sterile surgical pack on the Mayo stand. Click to open, reveals instruments + list paper.

signal opened()

@onready var wrap: MeshInstance3D = $WrapMesh
@onready var area: Area3D = $PackArea
@onready var paper: Label3D = $"../Paper"

var _opened: bool = false


func is_opened() -> bool:
	return _opened


func open() -> void:
	if _opened:
		return
	_opened = true
	area.set_deferred("collision_layer", 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wrap, "scale:y", 0.01, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(wrap, "position:y", wrap.position.y - 0.05, 0.45)
	tw.chain().tween_callback(_reveal_contents)


func _reveal_contents() -> void:
	wrap.visible = false
	if paper:
		paper.visible = true
	opened.emit()
