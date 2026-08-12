extends Node
## PlayerProfile autoload: cross-session player state, persisted to
## user://profile.cfg. Holds onboarding flags (later: progress, settings,
## best scores). The local file is the source of truth; backend sync is a
## future layer — see _push_to_backend().

const SAVE_PATH := "user://profile.cfg"
const SECTION_ONBOARDING := "onboarding"
const KEY_INTRO_SEEN := "intro_seen"

var _intro_seen := false


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


# ---------------- Persistence ----------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first launch / missing file — defaults stand
	_intro_seen = cfg.get_value(SECTION_ONBOARDING, KEY_INTRO_SEEN, false)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_ONBOARDING, KEY_INTRO_SEEN, _intro_seen)
	cfg.save(SAVE_PATH)


# ---------------- Backend sync (future) ----------------

func _push_to_backend() -> void:
	## TODO: upload profile payload to server once auth + backend exist.
	## Local save (_save) remains the offline cache / fallback.
	pass
