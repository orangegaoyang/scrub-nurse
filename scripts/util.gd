class_name Util
## Stateless utility helpers shared across scenes.

static func wait(seconds: float) -> void:
	## Await a plain seconds-long pause on the main scene tree.
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout
