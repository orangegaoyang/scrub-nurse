extends CanvasLayer
## Cross-scene fade transition. fade_out() covers the screen black before a
## scene change; the new scene calls fade_in() to reveal itself. The
## autoload persists across scene swaps, so the screen stays black during loading.

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_fit()
	get_viewport().size_changed.connect(_fit)


func fade_out(duration: float = 0.8) -> void:
	# Block input while the screen is covered.
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration: float = 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, duration)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fit() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = s
