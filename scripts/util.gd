class_name Util
## Stateless utility helpers shared across scenes.

const VOICE_DIR := "res://assets/audio"
const TOON_SHADER := preload("res://shaders/toon.gdshader")


static func apply_toon(node: Node) -> void:
	## Recursively swap every MeshInstance3D in the subtree to the shared toon
	## material, keeping the original albedo texture and base colour. Backfaces
	## render too (the shader is cull_disabled), which also fixes the room's
	## see-through backs.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(i)
				if mat == null:
					mat = mi.mesh.surface_get_material(i)
				var sm := ShaderMaterial.new()
				sm.shader = TOON_SHADER
				if mat is StandardMaterial3D:
					var std := mat as StandardMaterial3D
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
					sm.set_shader_parameter("tint", std.albedo_color)
				mi.set_surface_override_material(i, sm)
	for c in node.get_children():
		apply_toon(c)


static func tint_toon(node: Node, tint_color: Color) -> void:
	## Override the toon material's tint on every MeshInstance3D in the subtree
	## (after apply_toon has run) — a cheap way to recolor a low-poly model to
	## match art direction without touching the mesh. Pass a color near 1.0 in
	## the channels you want to keep (e.g. warm ivory = Color(0.93,0.9,0.83)).
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(i)
				if mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter("tint", tint_color)
	for c in node.get_children():
		tint_toon(c, tint_color)


static func wait(seconds: float) -> void:
	## Await a plain seconds-long pause on the main scene tree.
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


static func find_ancestor(node: Node, klass: Variant) -> Node:
	## Walk up to 3 levels looking for an ancestor of the given class (pass a
	## global class script, e.g. `BackZone`, or a native class name string).
	## Instruments hang off anchors, which may sit one or two levels below
	## their table/zone root — this makes parent checks robust to both.
	var p: Node = node
	for i in 3:
		if p == null:
			return null
		if is_instance_of(p, klass):
			return p
		p = p.get_parent()
	return null


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


static func play_voice(player: AudioStreamPlayer,  key: String, sub_path:String="") -> void:
	## Plays <VOICE_DIR>/<key>.wav on `player` if present; silent otherwise.
	var path = "%s/%s.wav" % [VOICE_DIR, key]
	if (!sub_path.is_empty()):
		path = "%s/%s/%s.wav" % [VOICE_DIR, sub_path,key]
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStream:
		player.stream = s
		player.play()
