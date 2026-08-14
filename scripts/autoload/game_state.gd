extends Node
## GameState autoload: phase state machine + scoring.

signal phase_changed(new_phase: int)
signal prep_completed()
signal prep_item_secured(instrument_id: String)
signal surgery_step_completed(step_index: int)
signal score_updated()
signal held_changed(instrument)

enum Phase { PREP, COUNTDOWN, SURGERY, RESULT }

var current_phase: int = Phase.PREP:
	set(v):
		current_phase = v
		phase_changed.emit(v)

# Prep scoring
var prep_correct: int = 0  # number of instruments placed correctly

# Surgery scoring
var surgery_correct: int = 0
var surgery_wrong: int = 0
var surgery_start_time: float = 0.0
var surgery_elapsed: float = 0.0
var current_demand_index: int = 0

# Currently held instrument (null when nothing held)
var held_instrument = null

# ---------------- Day selection (intro schedule board) ----------------
# Set when the player clicks a surgery row on the intro schedule; the rest of
# the day's flow can use it. Not cleared by reset(): the selection is made in
# the intro scene, and main.gd calls reset() after it.
var selected_surgery_index: int = -1
var selected_surgery: Dictionary = {}

const TOTAL_STEPS: int = 6


func reset() -> void:
	current_phase = Phase.PREP
	prep_correct = 0
	surgery_correct = 0
	surgery_wrong = 0
	surgery_start_time = 0.0
	surgery_elapsed = 0.0
	current_demand_index = 0
	set_held(null)
	score_updated.emit()


func set_held(inst) -> void:
	held_instrument = inst
	held_changed.emit(inst)


func start_countdown() -> void:
	prep_completed.emit()
	current_phase = Phase.COUNTDOWN


func start_surgery() -> void:
	current_phase = Phase.SURGERY
	surgery_start_time = Time.get_ticks_msec() / 1000.0
	current_demand_index = 0


func record_correct() -> void:
	surgery_correct += 1
	current_demand_index += 1
	score_updated.emit()
	if current_demand_index >= TOTAL_STEPS:
		finish_surgery()


func record_wrong() -> void:
	surgery_wrong += 1
	score_updated.emit()


func finish_surgery() -> void:
	surgery_elapsed = (Time.get_ticks_msec() / 1000.0) - surgery_start_time
	current_phase = Phase.RESULT


func get_stars() -> int:
	# Stars based on correctness; wrong attempts reduce stars.
	var total_attempts: int = surgery_correct + surgery_wrong
	if total_attempts == 0:
		return 0
	var ratio: float = float(surgery_correct) / float(total_attempts)
	if ratio >= 0.95:
		return 3
	elif ratio >= 0.8:
		return 2
	else:
		return 1
