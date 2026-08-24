class_name TableSlot
extends Area3D
## A placement slot. Three flavours, chosen by exports:
##   - Mayo slot (category == "", accept_any == false): accepts the instrument
##     whose slot_index matches (prep layout + surgery Level I guidance).
##   - Back table zone (category != ""): accepts any instrument of that
##     category (always hard-judged; wrong category bounces).
##   - Free cell (accept_any == true): accepts anything (surgery Level II/III).
## The white Highlight frame is plain scene content (a PNG on a Sprite3D):
## it shows in the EDITOR so slots can be dragged into place, and the game
## starts with it hidden — the placement feedback logic lights it on demand.

@export var slot_index: int = -1
@export var category: String = ""
@export var accept_any: bool = false
var occupied: bool = false
var current_instrument: Instrument = null

const COLOR_PLACE := Color(1, 1, 1, 0.9)
const COLOR_GHOST := Color(0.4, 0.85, 1.0, 0.95)
const COLOR_OK := Color(0.4, 0.9, 0.45, 1)
const COLOR_BAD := Color(0.95, 0.3, 0.3, 1)

@onready var highlight: Sprite3D = $Highlight
var _ghost_tw: Tween = null
var _hide_tw: Tween = null


func _ready() -> void:
	# Game: start hidden; placement feedback lights it up on demand.
	highlight.visible = false
	GameState.held_changed.connect(_on_held_changed)


func can_accept(inst: Instrument) -> bool:
	if inst == null or inst.def == null:
		return false
	if accept_any:
		return true
	if category != "":
		return inst.def.category == category
	return inst.def.slot_index == slot_index


func show_place_highlight() -> void:
	_kill_ghost()
	_kill_hide()
	if highlight.visible and highlight.modulate == COLOR_PLACE:
		return  # already up — per-frame drivers call this every frame
	_tint(COLOR_PLACE)
	_pop_in()


func show_ghost() -> void:
	## Cyan pulsing frame: "this cell is where the instrument conventionally
	## goes" (Level II guidance only).
	if highlight and highlight.visible and highlight.modulate == COLOR_GHOST:
		return
	_kill_ghost()
	_tint(COLOR_GHOST)
	_pop_in()
	_ghost_tw = create_tween().set_loops()
	_ghost_tw.tween_property(highlight, "scale", Vector3.ONE * 1.25, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ghost_tw.tween_property(highlight, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func hide_highlight() -> void:
	_kill_ghost()
	if highlight == null or not highlight.visible:
		return
	if _hide_tw != null and _hide_tw.is_valid():
		return  # fade already running — per-frame drivers call this every frame
	_hide_tw = create_tween()
	_hide_tw.tween_property(highlight, "scale", Vector3.ZERO, 0.12)
	_hide_tw.tween_callback(func(): highlight.visible = false)


func set_feedback(correct: bool) -> void:
	_kill_ghost()
	_kill_hide()
	_tint(COLOR_OK if correct else COLOR_BAD)
	_pop_in()
	if not correct:
		await Util.wait(0.3)
		hide_highlight()


func clear_feedback() -> void:
	hide_highlight()


func _kill_ghost() -> void:
	if _ghost_tw != null and _ghost_tw.is_valid():
		_ghost_tw.kill()
	_ghost_tw = null


func _kill_hide() -> void:
	if _hide_tw != null and _hide_tw.is_valid():
		_hide_tw.kill()
	_hide_tw = null


func _on_held_changed(inst) -> void:
	# Prep drives slot placement highlights; surgery drives highlights
	# per-frame via the surgery system.
	if GameState.current_phase != GameState.Phase.PREP:
		hide_highlight()
		return
	if inst != null and can_accept(inst) and not occupied:
		show_place_highlight()
	else:
		hide_highlight()


func _pop_in() -> void:
	highlight.visible = true
	highlight.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(highlight, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _tint(color: Color) -> void:
	highlight.modulate = color
