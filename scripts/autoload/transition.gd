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


func fade_to(alpha: float, duration: float) -> void:
	## Tween the black cover to a partial opacity. Used for cinematic dims
	## that blend into a later full fade_out; blocks input while dimmed.
	_rect.color = Color(0, 0, 0, _rect.color.a)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func fade_out(duration: float = 0.8) -> void:
	# Block input while the screen is covered.
	_rect.color = Color(0, 0, 0, _rect.color.a)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func cover_now() -> void:
	# Snap to full black in a single frame: guards the one-frame gap of a
	# scene swap without adding any perceived black time. The incoming scene
	# reveals itself immediately.
	_rect.color = Color(0, 0, 0, 1)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func flash_white(duration: float = 0.25) -> void:
	# Ramp a WHITE cover up: reads as the room lights snapping on in the
	# dark. The next scene reveals itself from this white via
	# fade_in_from_white().
	_rect.color = Color(1, 1, 1, _rect.color.a)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func fade_in(duration: float = 0.8) -> void:
	_rect.color = Color(0, 0, 0, _rect.color.a)
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_in_from_white(duration: float = 0.45) -> void:
	# Reveal the scene out of a white flash ("the lights are on now"), then
	# reset the cover to its normal black for future transitions.
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fit() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = s
