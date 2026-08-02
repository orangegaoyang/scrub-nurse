class_name Surgeon
extends Node3D
## Surgeon: a box-placeholder "hand" that slides into view from the upper-right
## to demand / return an instrument. The real hand model replaces the box
## later. Keeps the same signal/method API the surgery system & HUD/bubble rely
## on (demand_changed / returning_instrument / hand_retracted / try_receive /
## take_back / is_demanding / is_returning / get_hand_area / held_instrument).
##
## Hand states, mapped to screen motion:
##   DEMANDING — hand extended (slide in), asking for current_demand_id.
##   USING     — hand retracted (slide out) while using the delivered instrument.
##   RETURNING — hand extended again, holding the used instrument for take-back.
##
## Both the use duration and the demand cadence shrink as the procedure
## progresses (driven by current_demand_index) so the rhythm accelerates.

signal demand_changed(instrument_id: String)
signal returning_instrument(instrument_id: String)
signal hand_retracted()

enum State { IDLE, DEMANDING, USING, RETURNING }

const EXTENDED_POS := Vector3(0.36, 1.55, -0.15)
const RETRACTED_POS := Vector3(0.85, 1.70, -0.05)
const SLIDE_TIME := 0.25
const RECEIVE_PAUSE := 1.0  # hand holds the just-received instrument before retracting
const USE_DURATION_MAX := 1.8
const USE_DURATION_MIN := 0.8

var state: int = State.IDLE
var current_demand_id: String = ""
var held_instrument: Instrument = null

@onready var pivot: Node3D = $HandPivot
@onready var hand_area: Area3D = $HandPivot/HandArea
@onready var held_anchor: Node3D = $HandPivot/HeldAnchor
@onready var voice: AudioStreamPlayer = $Voice

var _reject_cooldown: bool = false
var _move: Tween = null


func _ready() -> void:
	pivot.position = RETRACTED_POS


func _move_to(pos: Vector3) -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = create_tween()
	_move.tween_property(pivot, "position", pos, SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func start_demand(id: String, hand_already_out: bool = false) -> void:
	current_demand_id = id
	state = State.DEMANDING
	held_instrument = null
	if not hand_already_out:
		_move_to(EXTENDED_POS)
	demand_changed.emit(id)
	_play_voice(id)


func is_demanding() -> bool:
	return state == State.DEMANDING


func is_returning() -> bool:
	return state == State.RETURNING


func get_hand_area() -> Area3D:
	return hand_area


func try_receive(inst: Instrument) -> bool:
	if state != State.DEMANDING or _reject_cooldown:
		return false
	if inst.instrument_id == current_demand_id:
		held_instrument = inst
		inst.set_state(Instrument.State.IN_SURGEON)
		inst.reparent(held_anchor)
		inst.transform = Transform3D.IDENTITY
		state = State.USING
		_use_sequence()
		return true
	else:
		_reject()
		return false


func _reject() -> void:
	GameState.record_wrong()
	_move_to(RETRACTED_POS)
	hand_retracted.emit()
	_reject_cooldown = true
	await get_tree().create_timer(0.6).timeout
	_reject_cooldown = false
	if state == State.DEMANDING:
		_move_to(EXTENDED_POS)
		demand_changed.emit(current_demand_id)
		_play_voice(current_demand_id)


func _use_sequence() -> void:
	# 1) Hold the just-received instrument out for a beat so the grab reads,
	#    then 2) retract to use, then 3) extend again to return it.
	await get_tree().create_timer(RECEIVE_PAUSE).timeout
	if state != State.USING:
		return
	_move_to(RETRACTED_POS)
	# Surgeon uses the instrument faster as the procedure goes on.
	var total: int = ProcedureData.demand_sequence.size()
	var t: float = clampf(float(GameState.current_demand_index) / float(maxi(total - 1, 1)), 0.0, 1.0)
	var dur: float = lerpf(USE_DURATION_MAX, USE_DURATION_MIN, t)
	await get_tree().create_timer(dur).timeout
	if state == State.USING:
		state = State.RETURNING
		_move_to(EXTENDED_POS)
		returning_instrument.emit(current_demand_id)


func take_back(keep_hand_out: bool = false) -> void:
	held_instrument = null
	state = State.IDLE
	if not keep_hand_out:
		_move_to(RETRACTED_POS)
		hand_retracted.emit()


func _play_voice(id: String) -> void:
	# Plays assets/audio/<id>.wav if present; silent otherwise (audio TBD).
	var path := "res://assets/audio/%s.wav" % id
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		voice.stream = s
		voice.play()
