class_name Surgeon
extends Node3D
## Surgeon: a box-placeholder "hand" that slides into view from the upper-right
## to demand an instrument, retracts to use it, then returns to deposit it in
## the neutral-zone tray — WITHOUT waiting for the nurse to collect it. If the
## tray is full the hand waits, holding the used instrument (the single
## back-pressure valve). Keeps the same signal/method API the surgery system &
## HUD/bubble rely on (demand_changed / instrument_deposited / hand_retracted /
## try_receive / is_demanding / get_hand_area / held_instrument / finish_use /
## release_to_zone).
##
## Hand states, mapped to screen motion:
##   DEMANDING  — hand at the MAYO front edge, asking for the instrument.
##   USING      — hand retracted (slide out) while using the delivered instrument.
##   DEPOSITING — hand at the NEUTRAL-ZONE front edge, about to release.
##   WAITING    — hand over the tray holding the instrument; tray is full.
## Two extended positions: the hand slides between the mayo front (demand)
## and the zone front (deposit), and retracts while using.

signal demand_changed(instrument_id: String)
signal instrument_deposited(instrument_id: String)
signal returning_instrument(instrument_id: String)
signal hand_retracted()

enum State { IDLE, DEMANDING, USING, RETURNING, DEPOSITING, WAITING }

const SLIDE_TIME := 0.25
const RECEIVE_PAUSE := 1.0  # hand holds the just-received instrument before retracting

var state: int = State.IDLE
var current_demand_id: String = ""
var held_instrument: Instrument = null
var zone: Node3D = null  # NeutralZone, injected by the surgery system

@onready var pivot: Node3D = $HandPivot
@onready var hand_area: Area3D = $HandPivot/HandArea
@onready var held_anchor: Node3D = $HandPivot/HeldAnchor
@onready var voice: AudioStreamPlayer = $Voice
# Extended/deposit poses come from the editor: drag the PoseMarkers in the
# MAIN scene to re-stage the doctor's reach. The retracted pose is the
# HandPivot's own editor transform — no marker, the editor pose is truth.
#@onready var _extended_pos: Vector3 = $PoseMarkers/ExtendedPos.position
var _extended_pos: Vector3 = Vector3(0.8,1.3,0)
#@onready var _deposit_pos: Vector3 = $PoseMarkers/DepositPos.position
var _deposit_pos: Vector3 = Vector3(1.1,1.3,0)

var _retracted_pos := Vector3.ZERO

var _reject_cooldown: bool = false
var _move: Tween = null


func _ready() -> void:
	# Capture the HandPivot's editor pose before any move tween touches it:
	# that pose IS the retracted (using / idle / final) position.
	_retracted_pos = pivot.position


func _move_to(pos: Vector3) -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = create_tween()
	_move.tween_property(pivot, "position", pos, SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func start_demand(id: String) -> void:
	current_demand_id = id
	state = State.DEMANDING
	held_instrument = null
	# Always slide to the mayo front: first demand comes from the retracted
	# pose, later ones from the deposit pose at the zone front.
	_move_to(_extended_pos)
	demand_changed.emit(id)
	Util.play_voice(voice, id)


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
		_move_to(_retracted_pos)
		return true
	else:
		_reject()
		return false


func _reject() -> void:
	GameState.record_wrong()
	_move_to(_retracted_pos)
	hand_retracted.emit()
	_reject_cooldown = true
	await Util.wait(0.6)
	_reject_cooldown = false
	if state == State.DEMANDING:
		_move_to(_extended_pos)
		demand_changed.emit(current_demand_id)
		Util.play_voice(voice, current_demand_id)


func finish_use() -> void:
	## Called by the surgery system once the use duration elapses: bring the
	## hand + instrument out to the neutral-zone front, ready to release.
	if state != State.USING or held_instrument == null:
		return
	state = State.DEPOSITING
	_move_to(_deposit_pos)


func return_instrument() -> void:
	## S1 (no neutral zone): the doctor hands the used instrument back
	## directly — hand extends to the mayo front holding it, clickable.
	if state != State.USING or held_instrument == null:
		return
	state = State.RETURNING
	_move_to(_extended_pos)
	held_instrument.collision_layer = 1
	returning_instrument.emit(held_instrument.instrument_id)


func take_back() -> void:
	## The nurse collected the returned instrument from the hand.
	held_instrument = null
	state = State.IDLE
	hand_retracted.emit()


func release_to_zone() -> bool:
	## Drop the held instrument into the neutral-zone tray. Returns false when
	## the tray is full (hand waits, instrument stays in hand).
	if zone == null or held_instrument == null:
		return false
	var inst: Instrument = held_instrument
	var anchor: Node3D = zone.call("place_instrument", inst)
	if anchor == null:
		state = State.WAITING
		return false
	held_instrument = null
	state = State.IDLE
	instrument_deposited.emit(inst.instrument_id)
	return true


func discard_held() -> void:
	## The doctor keeps the used gauze off-frame — it simply never comes back.
	## No toss, no basin: the hand stays retracted and the line continues on
	## the system's clock.
	if state != State.USING or held_instrument == null:
		return
	var inst: Instrument = held_instrument
	held_instrument = null
	state = State.IDLE
	GameState.discarded_count += 1
	instrument_deposited.emit(inst.instrument_id)
	inst.queue_free()


func hand_waiting() -> bool:
	return state == State.WAITING


func retract() -> void:
	## Doctor's line is finished: pull the hand away.
	state = State.IDLE
	held_instrument = null
	_move_to(_retracted_pos)
	hand_retracted.emit()
