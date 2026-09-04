extends Node
## Audio autoload: cross-scene music + ambience bed. Both loop from launch and
## survive scene changes (scene-local players would cut out on change_scene).
## Live levels sit on the Music/Ambience buses; per-scene ducking or swapping
## can be added through this API later.

const BGM_PATH := "res://assets/audio/bgm/hospital_day.ogg"
const AMBIENCE_PATH := "res://assets/audio/ambience/hospital_ambience.ogg"
const MUSIC_DB := -12.7

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer

var _music_tween: Tween


func _ready() -> void:
	music = _make_player(&"Music", BGM_PATH, MUSIC_DB)
	#ambience = _make_player(&"Ambience", AMBIENCE_PATH, -15.0)


func duck_music(db: float, time: float) -> void:
	## 手术节奏期间把 BGM 压低,给节拍层让路(由 Conductor 调用)。
	_tween_music(db, time)


func restore_music(time: float = 1.0) -> void:
	_tween_music(MUSIC_DB, time)


func _tween_music(db: float, time: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", db, time)


func _make_player(bus: StringName, path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = volume_db
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		p.stream = stream
	add_child(p)
	p.play()
	return p
