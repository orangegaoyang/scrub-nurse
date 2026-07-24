class_name Surgeon
extends Node3D
## Surgeon hand: enters from the right side. Demand state machine.

enum State { IDLE, DEMANDING, USING, RETURNING }

signal demand_changed(instrument_id: String)
signal returning_instrument(instrument_id: String)

var state: int = State.IDLE
var current_demand_id: String = ""
var held_instrument: Instrument = null

@onready var hand_pivot: Node3D = $HandPivot
@onready var hand_area: Area3D = $HandPivot/HandArea
@onready var held_anchor: Node3D = $HandPivot/HeldAnchor

const HAND_EXTENDED_X: float = -1.0   # toward the table/player (left), into view
const HAND_RETRACTED_X: float = 0.3   # off to the right (out of view)
const USE_DURATION: float = 1.8

var _reject_cooldown: bool = false


func _ready() -> void:
	_retract_hand()


func start_demand(id: String) -> void:
	current_demand_id = id
	state = State.DEMANDING
	held_instrument = null
	_extend_hand()
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
		_retract_hand()
		state = State.USING
		_use_after_delay()
		return true
	else:
		_reject()
		return false


func _reject() -> void:
	GameState.record_wrong()
	_retract_hand()
	_reject_cooldown = true
	await get_tree().create_timer(0.6).timeout
	_reject_cooldown = false
	if state == State.DEMANDING:
		_extend_hand()


func _use_after_delay() -> void:
	await get_tree().create_timer(USE_DURATION).timeout
	if state == State.USING:
		state = State.RETURNING
		_extend_hand()
		returning_instrument.emit(current_demand_id)


func take_back() -> void:
	held_instrument = null
	_retract_hand()
	state = State.IDLE


func _extend_hand() -> void:
	var tw := create_tween()
	tw.tween_property(hand_pivot, "position:x", HAND_EXTENDED_X, 0.3)


func _retract_hand() -> void:
	var tw := create_tween()
	tw.tween_property(hand_pivot, "position:x", HAND_RETRACTED_X, 0.3)
