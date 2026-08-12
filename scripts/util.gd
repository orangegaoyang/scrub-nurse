class_name Util
## Stateless utility helpers shared across scenes.

const VOICE_DIR := "res://assets/audio"


static func wait(seconds: float) -> void:
	## Await a plain seconds-long pause on the main scene tree.
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


static func play_voice(player: AudioStreamPlayer, key: String) -> void:
	## Plays <VOICE_DIR>/<key>.wav on `player` if present; silent otherwise.
	var path := "%s/%s.wav" % [VOICE_DIR, key]
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		player.stream = s
		player.play()
