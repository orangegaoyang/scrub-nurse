extends Node
## Audio autoload: cross-scene music + ambience bed. Both loop from launch and
## survive scene changes (scene-local players would cut out on change_scene).
## Live levels sit on the Music/Ambience buses; per-scene ducking or swapping
## can be added through this API later.

const BGM_PATH := "res://assets/audio/bgm/hospital_day.ogg"
const AMBIENCE_PATH := "res://assets/audio/ambience/hospital_ambience.ogg"

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer


func _ready() -> void:
	music = _make_player(&"Music", BGM_PATH, -12.7)
	ambience = _make_player(&"Ambience", AMBIENCE_PATH, -20.0)


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
