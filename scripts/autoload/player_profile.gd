extends Node
## PlayerProfile autoload: cross-session player state, persisted to
## user://profile.cfg. Holds onboarding flags and career progress: each star
## earned feeds BOTH pools below.
##   1. Global seniority (total stars) -> nurse Level I/II/III -> gates access
##      to higher-level surgeries (Level III surgery needs Level III nurse).
##   2. Per-procedure familiarity (stars in that procedure) -> that procedure's
##      Level I/II/III -> drives slot guidance there (L1 hard slots,
##      L2 free cells + ghost hints, L3 free cells only).
## The local file is the source of truth; backend sync is a future layer —
## see _push_to_backend().

const SAVE_PATH := "user://profile.cfg"
const SECTION_ONBOARDING := "onboarding"
const KEY_INTRO_SEEN := "intro_seen"
const SECTION_PROGRESS := "progress"
const KEY_TOTAL_STARS := "total_stars"
const KEY_PROC_STARS := "proc_stars"
const KEY_PROCEDURES := "procedures_completed"

# Level thresholds (cumulative stars) — tune after playtesting.
const LEVEL2_STARS := 5
const LEVEL3_STARS := 12

var _intro_seen := false
var _total_stars := 0
var _proc_stars := {}  # procedure id -> stars


func _ready() -> void:
	_load()


# ---------------- Onboarding ----------------

var intro_seen: bool:
	get:
		return _intro_seen


func mark_intro_seen() -> void:
	if _intro_seen:
		return
	_intro_seen = true
	_save()
	_push_to_backend()


# ---------------- Career progress ----------------

var total_stars: int:
	get:
		return _total_stars


func procedure_stars(proc_id: String) -> int:
	return int(_proc_stars.get(proc_id, 0))


func add_surgery_result(proc_id: String, stars: int) -> void:
	if proc_id.is_empty() or stars <= 0:
		return
	_total_stars += stars
	_proc_stars[proc_id] = int(_proc_stars.get(proc_id, 0)) + stars
	_save()
	_push_to_backend()


func global_level() -> int:
	return _level_from_stars(_total_stars)


func procedure_level(proc_id: String) -> int:
	return _level_from_stars(procedure_stars(proc_id))


func _level_from_stars(stars: int) -> int:
	if stars >= LEVEL3_STARS:
		return 3
	if stars >= LEVEL2_STARS:
		return 2
	return 1


# ---------------- Persistence ----------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first launch / missing file — defaults stand
	_intro_seen = cfg.get_value(SECTION_ONBOARDING, KEY_INTRO_SEEN, false)
	_total_stars = int(cfg.get_value(SECTION_PROGRESS, KEY_TOTAL_STARS, 0))
	_proc_stars = cfg.get_value(SECTION_PROGRESS, KEY_PROC_STARS, {})


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_ONBOARDING, KEY_INTRO_SEEN, _intro_seen)
	cfg.set_value(SECTION_PROGRESS, KEY_TOTAL_STARS, _total_stars)
	cfg.set_value(SECTION_PROGRESS, KEY_PROC_STARS, _proc_stars)
	cfg.set_value(SECTION_PROGRESS, KEY_PROCEDURES, _proc_stars.size())
	cfg.save(SAVE_PATH)


# ---------------- Backend sync (future) ----------------

func _push_to_backend() -> void:
	## TODO: upload profile payload to server once auth + backend exist.
	## Local save (_save) remains the offline cache / fallback.
	pass
