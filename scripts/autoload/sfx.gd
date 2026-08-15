extends Node
## Sfx autoload: pooled one-shot sound effects. Drop a file at
## res://assets/audio/sfx/<key>.wav (or .ogg) and the matching Sfx.play("key")
## call just starts working; missing files are silent no-ops. Every play gets
## a small random pitch shift so repeated effects don't sound robotic. All
## players route to the dedicated "SFX" bus (see the bus layout).

const SFX_DIR := "res://assets/audio/sfx"
const POOL_SIZE := 8
const PITCH_JITTER := 0.05

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}  # key -> AudioStream


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)


func play(key: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _cache.get(key)
	if stream == null:
		stream = _load_stream(key)
		if stream == null:
			return  # asset not added yet — stay silent
		_cache[key] = stream
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	p.play()


func _load_stream(key: String) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s/%s.%s" % [SFX_DIR, key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null
