class_name Util
## Stateless utility helpers shared across scenes.

const VOICE_DIR := "res://assets/audio"


static func wait(seconds: float) -> void:
	## Await a plain seconds-long pause on the main scene tree.
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


static func mouse_to_plane(camera: Camera3D, mouse_pos: Vector2, plane_y: float) -> Vector3:
	## Where the cursor ray crosses the horizontal plane at `plane_y`.
	## Returns Vector3.INF when the ray is parallel to the plane or the
	## crossing lies behind the camera.
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - from.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t


static func normalized_mouse(mouse: Vector2, size: Vector2) -> Vector2:
	## Cursor position mapped to -1..1 across the viewport, clamped. Shared by
	## the parallax helper and the badge's cursor sway.
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(mouse.x / size.x * 2.0 - 1.0, -1.0, 1.0),
		clampf(mouse.y / size.y * 2.0 - 1.0, -1.0, 1.0))


static func parallax_offset(camera: Camera3D, plane_y: float, px: float) -> Vector3:
	## Idle mouse parallax: a world-space offset on the horizontal plane at
	## `plane_y` that follows the cursor, reaching roughly `px` screen pixels
	## at full cursor travel. Screen right maps to world +X and screen up maps
	## to the table's far side. Used by the intro props (badge 3 px,
	## clipboard 1 px) for the barely-there depth feel.
	var vp := camera.get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return Vector3.ZERO
	var n := normalized_mouse(camera.get_viewport().get_mouse_position(), vp)
	var d := (camera.global_position - Vector3(0.0, plane_y, 0.0)).length()
	var world_per_px := 2.0 * d * tan(deg_to_rad(camera.fov * 0.5)) / vp.y
	var right := camera.global_transform.basis.x
	right.y = 0.0
	var up := camera.global_transform.basis.y
	up.y = 0.0
	if up.length_squared() < 0.0001:
		up = Vector3(0.0, 0.0, 1.0)
	up = up.normalized()
	if right.length_squared() < 0.0001:
		right = Vector3(1.0, 0.0, 0.0)
	right = right.normalized()
	return (right * n.x - up * n.y) * px * world_per_px


static func play_voice(player: AudioStreamPlayer, key: String) -> void:
	## Plays <VOICE_DIR>/<key>.wav on `player` if present; silent otherwise.
	var path := "%s/%s.wav" % [VOICE_DIR, key]
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		player.stream = s
		player.play()
