class_name Surgeon
extends Node3D
## Surgeon: a rigged doctor model that plays a "Reach" arm animation when
## demanding / returning an instrument. The HandArea sits at the reach pose.

enum State { IDLE, DEMANDING, USING, RETURNING }

signal demand_changed(instrument_id: String)
signal returning_instrument(instrument_id: String)
signal hand_retracted()

const REACH_ANIM := "Reach"

var state: int = State.IDLE
var current_demand_id: String = ""
var held_instrument: Instrument = null

@onready var hand_area: Area3D = $DoctorModel/HandArea
@onready var held_anchor: Node3D = $DoctorModel/HeldAnchor
@onready var anim: AnimationPlayer = _find_anim()
const USE_DURATION: float = 1.8

var _reject_cooldown: bool = false


func _find_anim() -> AnimationPlayer:
	var n := get_node_or_null("DoctorModel")
	if n:
		var ap := n.find_child("AnimationPlayer", true, false)
		if ap:
			return ap
	return null


func _ready() -> void:
	# Park the doctor in the rest pose (arms down), not the T-pose.
	if anim and anim.has_animation(REACH_ANIM):
		anim.play(REACH_ANIM)
		anim.pause()
		anim.seek(0.0, true)


func start_demand(id: String, hand_already_out: bool = false) -> void:
	current_demand_id = id
	state = State.DEMANDING
	held_instrument = null
	if not hand_already_out:
		_play_reach(true)
	demand_changed.emit(id)


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
		_play_reach(false)   # pull hand back to use
		state = State.USING
		_use_after_delay()
		return true
	else:
		_reject()
		return false


func _reject() -> void:
	GameState.record_wrong()
	_play_reach(false)   # hand comes back
	hand_retracted.emit()
	_reject_cooldown = true
	await get_tree().create_timer(0.6).timeout
	_reject_cooldown = false
	if state == State.DEMANDING:
		_play_reach(true)
		demand_changed.emit(current_demand_id)


func _use_after_delay() -> void:
	await get_tree().create_timer(USE_DURATION).timeout
	if state == State.USING:
		state = State.RETURNING
		_play_reach(true)   # extend hand to give the instrument back
		returning_instrument.emit(current_demand_id)


func take_back(keep_hand_out: bool = false) -> void:
	held_instrument = null
	state = State.IDLE
	if not keep_hand_out:
		_play_reach(false)
		hand_retracted.emit()


func _play_reach(extend: bool) -> void:
	if anim == null or not anim.has_animation(REACH_ANIM):
		return
	if extend:
		anim.play(REACH_ANIM, 0.15)
	else:
		anim.play_backwards(REACH_ANIM, 0.15)
