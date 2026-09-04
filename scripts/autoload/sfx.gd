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
	var stream := _get_stream(key)
	if stream == null:
		return
	_start(stream, volume_db, randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER))


func play_pitched(key: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	## 固定音高播放(节奏用):递送"啪"按器械类别定音高,操作本身构成旋律。
	var stream := _get_stream(key)
	if stream == null:
		return
	_start(stream, volume_db, pitch)


func _start(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _get_stream(key: String) -> AudioStream:
	var stream: AudioStream = _cache.get(key)
	if stream == null:
		stream = _load_stream(key)
		if stream == null:
			return null  # asset not added yet — stay silent
		_cache[key] = stream
	return stream


func _load_stream(key: String) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s/%s.%s" % [SFX_DIR, key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null
