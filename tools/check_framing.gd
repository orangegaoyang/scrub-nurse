extends Node
## Headless framing verification: projects key world points through all three
## cameras and asserts they land inside the viewport with sane spread, then
## pixel-diffs the windowed captures (tools/captures/*.png) to verify the
## neutral-zone deposit and back-table stocking actually rendered.
## Run AFTER the windowed capture: godot --headless --path . res://tools/check_framing.tscn

const MAIN := preload("res://scenes/main.tscn")
const CAP_DIR := "res://tools/captures"

var fails: Array[String] = []
var vp_size := Vector2.ZERO


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)  # match the real windowed render aspect
	GameState.selected_surgery = {"procedure": "Craniotomy", "level": 3}  # S3: full set
	var main: Node = MAIN.instantiate()
	add_child(main)
	_run(main)


func _run(main: Node) -> void:
	await Util.wait(3.4)  # same settle point as the capture run
	vp_size = get_viewport().get_visible_rect().size
	print("headless viewport: ", vp_size)
	var ui: Node = main.get_node("UI")
	_check(ui.visible, "UI layer visible at runtime")
	_check(main.get_node("UI/InstrumentList").visible, "instrument list visible during prep")
	var cam_prep: Camera3D = main.get_node("CameraPrep")
	var cam_mayo: Camera3D = main.get_node("CameraMayo")
	var cam_back: Camera3D = main.get_node("CameraBackTable")

	# -- Prep view: both table CENTERS must be in frame (hard); the outer
	# edges are reported as info only — the exact framing is the designer's
	# call and may intentionally clip the edges.
	var mayo_pos: Vector3 = main.get_node("MayoStand").global_position
	var prep_centers := {
		"back_table_center": Vector3(0.0, 0.86, 4.5),
		"mayo_prep_center": mayo_pos + Vector3(0, 0.91, 0),
	}
	for key in prep_centers:
		_check_in_view(cam_prep, prep_centers[key], "prep view shows " + key)
	var prep_edges := {
		"back_table_left": Vector3(-0.6, 0.86, 4.5),
		"back_table_right": Vector3(0.6, 0.86, 4.5),
		"mayo_prep_left": mayo_pos + Vector3(-0.45, 0.91, 0),
		"mayo_prep_right": mayo_pos + Vector3(0.45, 0.91, 0),
	}
	for key in prep_edges:
		_info_in_view(cam_prep, prep_edges[key], "prep view edge " + key)
	var bt := cam_prep.unproject_position(Vector3(0.0, 0.86, 4.5))
	var mp := cam_prep.unproject_position(mayo_pos + Vector3(0, 0.91, 0))
	var mayo_right_of_back: bool = mayo_pos.x > 0.0
	_check((mp.x > bt.x) == mayo_right_of_back,
		"prep view screen order matches the editor arrangement (no mirror)")

	# -- Surgery mayo view --
	var mayo_pts := {
		"mayo_tray_center": Vector3(0.522, 0.99, 0.073),
		"mayo_tray_left": Vector3(0.07, 0.99, 0.073),
		"mayo_tray_right": Vector3(0.97, 0.99, 0.073),
		"neutral_zone": Vector3(0.962, 0.97, 0.1),
		"hand_extended": Vector3(0.6, 1.22, -0.2),
		"hand_deposit": Vector3(0.96, 1.18, -0.02),
	}
	for key in mayo_pts:
		_check_in_view(cam_mayo, mayo_pts[key], "mayo view shows " + key)
	var mz := cam_mayo.unproject_position(Vector3(0.962, 0.97, 0.1))
	var mc := cam_mayo.unproject_position(Vector3(0.522, 0.99, 0.073))
	_check(mz.x > mc.x, "neutral zone renders right of mayo (surgeon side)")
	var hand := cam_mayo.unproject_position(Vector3(0.6, 1.22, -0.2))
	var hf := Vector2(hand.x / vp_size.x, hand.y / vp_size.y)
	_check(hf.y > 0.1 and hf.y < 0.5, "hand extended sits in the upper half of the mayo view (y=%.2f)" % hf.y)

	# -- Back view --
	var back_pts := {
		"table_center": Vector3(0.0, 0.86, 4.5),
		"zone_leftmost": Vector3(-0.48, 0.89, 4.5),
		"zone_rightmost": Vector3(0.48, 0.89, 4.5),
	}
	for key in back_pts:
		_check_in_view(cam_back, back_pts[key], "back view shows " + key)
	for entry in [
		{"x": -0.48}, {"x": -0.24}, {"x": 0.0}, {"x": 0.24}, {"x": 0.48},
	]:
		_check_in_view(cam_back, Vector3(entry["x"], 0.89, 4.5),
			"back view shows zone x=%.2f" % entry["x"])
	var xl := cam_back.unproject_position(Vector3(-0.48, 0.89, 4.5))
	var xr := cam_back.unproject_position(Vector3(0.48, 0.89, 4.5))
	var spread: float = absf(xr.x - xl.x) / vp_size.x
	_check(spread > 0.45, "back zones span %.0f%% of screen width" % (spread * 100.0))

	# -- Pixel checks on the windowed captures --
	var mayo_start := _load_png("surgery_mayo_start.png")
	var mayo_deposit := _load_png("surgery_zone_deposit.png")
	var back_empty := _load_png("surgery_back_empty.png")
	var back_filled := _load_png("surgery_back_filled.png")
	if mayo_start == null or mayo_deposit == null or back_empty == null or back_filled == null:
		fails.append("captures missing — run the windowed capture first")
	else:
		var scale := Vector2(float(mayo_start.get_width()) / vp_size.x, float(mayo_start.get_height()) / vp_size.y)
		print("png size: ", Vector2(mayo_start.get_width(), mayo_start.get_height()), " scale: ", scale)
		var zone_rect := _scaled_rect(_screen_rect(cam_mayo, [
			Vector3(0.83, 1.0, 0.1), Vector3(0.96, 1.0, 0.1), Vector3(1.09, 1.0, 0.1)
		], 26), scale)
		var zone_diff := _diff_count(mayo_start, mayo_deposit, zone_rect)
		_check(zone_diff > 80, "instrument visible in neutral zone (diff px: %d)" % zone_diff)

		var table_rect := _scaled_rect(_screen_rect(cam_back, [
			Vector3(-0.48, 0.9, 4.5), Vector3(0.48, 0.9, 4.5)
		], 30), scale)
		var back_diff := _diff_count(back_empty, back_filled, table_rect)
		_check(back_diff > 80, "scalpel visible on back table (diff px: %d)" % back_diff)
		var var_before := _luminance_variance(back_filled, table_rect)
		_check(var_before > 0.0004, "back table strip non-uniform (labels/plates/texture), var=%.5f" % var_before)

		# Prep view must not be dark: mean luminance over the tables region.
		var prep_png := _load_png("prep_view.png")
		if prep_png != null:
			var prep_rect := _scaled_rect(_screen_rect(cam_prep, [
				Vector3(-0.6, 0.95, 4.5), Vector3(0.0, 0.95, 4.5),
				main.get_node("MayoStand").global_position + Vector3(0, 0.9, 0),
			], 20), scale)
			var prep_mean := _mean_luminance(prep_png, prep_rect)
			_check(prep_mean > 0.18, "prep view is lit (mean luminance %.3f)" % prep_mean)

	print("== framing check done: %d fails ==" % fails.size())
	for f in fails:
		print("FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() else 1)


# ---------------- Checks ----------------

func _check_in_view(cam: Camera3D, world: Vector3, what: String) -> void:
	var p := cam.unproject_position(world)
	var fx: float = p.x / vp_size.x
	var fy: float = p.y / vp_size.y
	var margin: float = 0.05
	var inside: bool = fx > margin and fx < 1.0 - margin and fy > margin and fy < 1.0 - margin
	if not inside:
		fails.append("%s — projected to (%.2f, %.2f), outside frame" % [what, fx, fy])
	else:
		print("  ok: %s -> (%.2f, %.2f)" % [what, fx, fy])


func _info_in_view(cam: Camera3D, world: Vector3, what: String) -> void:
	var p := cam.unproject_position(world)
	var fx: float = p.x / vp_size.x
	var fy: float = p.y / vp_size.y
	var inside: bool = fx > 0.0 and fx < 1.0 and fy > 0.0 and fy < 1.0
	print("  info: %s -> (%.2f, %.2f) %s" % [what, fx, fy, "in frame" if inside else "CLIPPED"])


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: ", what)
	else:
		fails.append(what)
		print("  FAIL: ", what)


func _screen_rect(cam: Camera3D, world_pts: Array, pad: int) -> Rect2i:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for w in world_pts:
		var p := cam.unproject_position(w)
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var pos := Vector2i(int(min_p.x) - pad, int(min_p.y) - pad)
	var end := Vector2i(int(max_p.x) + pad, int(max_p.y) + pad)
	return Rect2i(pos, end - pos)


func _scaled_rect(rect: Rect2i, scale: Vector2) -> Rect2i:
	var pos := Vector2i(int(rect.position.x * scale.x), int(rect.position.y * scale.y))
	var end := Vector2i(int(rect.end.x * scale.x), int(rect.end.y * scale.y))
	return Rect2i(pos, end - pos)


func _load_png(name: String) -> Image:
	var path := "%s/%s" % [CAP_DIR, name]
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return null
	var img := Image.load_from_file(abs)
	return img


func _diff_count(a: Image, b: Image, rect: Rect2i) -> int:
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := (ca.r - cb.r) * (ca.r - cb.r) + (ca.g - cb.g) * (ca.g - cb.g) + (ca.b - cb.b) * (ca.b - cb.b)
			if d > 0.02:
				n += 1
	return n


func _luminance_variance(img: Image, rect: Rect2i) -> float:
	var samples: Array[float] = []
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x, rect.end.x, 3):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			samples.append(0.299 * c.r + 0.587 * c.g + 0.114 * c.b)
	if samples.size() < 2:
		return 0.0
	var mean: float = 0.0
	for s in samples:
		mean += s
	mean /= samples.size()
	var v: float = 0.0
	for s in samples:
		v += (s - mean) * (s - mean)
	return v / samples.size()


func _mean_luminance(img: Image, rect: Rect2i) -> float:
	var sum: float = 0.0
	var n: int = 0
	for y in range(rect.position.y, rect.end.y, 3):
		for x in range(rect.position.x, rect.end.x, 3):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			sum += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			n += 1
	if n == 0:
		return 0.0
	return sum / n
