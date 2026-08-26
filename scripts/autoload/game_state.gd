extends Node
## GameState autoload: phase state machine + scoring + tidy tracking.

signal phase_changed(new_phase: int)
signal prep_completed()
signal prep_item_secured(instrument_id: String)
signal prep_back_item_secured(instrument_id: String)
signal score_updated()
signal held_changed(instrument)
signal tidy_progress_changed(on_back_count: int)
signal hint_changed(text: String, ack: bool)
signal view_switched()
signal surgeon_line_start()

enum Phase { PREP, COUNTDOWN, SURGERY, TIDY, RESULT }

var current_phase: int = Phase.PREP:
	set(v):
		current_phase = v
		phase_changed.emit(v)

# Prep scoring
var prep_correct: int = 0  # number of instruments placed correctly
var prep_back_correct: int = 0  # instruments placed into back-table zones (slot_index >= 6)

# Surgery scoring
var surgery_correct: int = 0
var surgery_wrong: int = 0
var surgery_start_time: float = 0.0
var surgery_elapsed: float = 0.0
var current_demand_index: int = 0

# Tidy-up tracking (final clearing of neutral zone / mayo / hand)
var back_table_count: int = 0  # instruments currently placed in back table zones
var discarded_count: int = 0  # gauze the doctor disposed of himself — already handled
var tidy_skipped: bool = false
var last_stars: int = 0

# ---------------- Day selection (intro schedule board) ----------------
# Set when the player clicks a surgery row on the intro schedule; the rest of
# the day's flow can use it. Not cleared by reset(): the selection is made in
# the intro scene, and main.gd calls reset() after it.
var selected_surgery_index: int = -1
var selected_surgery: Dictionary = {}


func reset() -> void:
	current_phase = Phase.PREP
	prep_correct = 0
	prep_back_correct = 0
	surgery_correct = 0
	surgery_wrong = 0
	surgery_start_time = 0.0
	surgery_elapsed = 0.0
	current_demand_index = 0
	back_table_count = 0
	discarded_count = 0
	tidy_skipped = false
	last_stars = 0
	set_held(null)
	score_updated.emit()
	tidy_progress_changed.emit(0)


func set_held(inst) -> void:
	held_changed.emit(inst)


func current_procedure_id() -> String:
	## Per-procedure familiarity is keyed by the surgery picked on the intro
	## board; falls back to the procedure.json id when main is run directly.
	if not selected_surgery.is_empty() and selected_surgery.has("procedure"):
		return selected_surgery["procedure"]
	return ProcedureData.procedure_id


func guidance_tier() -> int:
	## Slot-guidance tier for the current procedure:
	##   1 = hard slots, 2 = free cells + ghost hints, 3 = free cells only.
	return PlayerProfile.procedure_level(current_procedure_id())


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


func record_wrong() -> void:
	surgery_wrong += 1
	score_updated.emit()


func start_tidy() -> void:
	## Doctor's line is done; the player clears everything to the back table.
	current_phase = Phase.TIDY
	tidy_progress_changed.emit(back_table_count)


func set_back_table_count(count: int) -> void:
	back_table_count = count
	if current_phase == Phase.TIDY:
		tidy_progress_changed.emit(count)
		if count >= ProcedureData.total_instances():
			finish_surgery(false)


func finish_surgery(skipped_tidy: bool = false) -> void:
	surgery_elapsed = (Time.get_ticks_msec() / 1000.0) - surgery_start_time
	tidy_skipped = skipped_tidy
	last_stars = get_stars()
	# One star feeds two pools: global seniority + this procedure's familiarity.
	PlayerProfile.add_surgery_result(current_procedure_id(), last_stars)
	current_phase = Phase.RESULT


func get_stars() -> int:
	# Stars based on correctness; wrong attempts reduce stars, and skipping
	# the final tidy-up with instruments left out costs one star each.
	var total_attempts: int = surgery_correct + surgery_wrong
	if total_attempts == 0:
		return 0
	var ratio: float = float(surgery_correct) / float(total_attempts)
	var base: int = 3 if ratio >= 0.95 else (2 if ratio >= 0.8 else 1)
	if tidy_skipped:
		var leftovers: int = ProcedureData.total_instances() - back_table_count
		base = max(1, base - max(0, leftovers))
	return base
