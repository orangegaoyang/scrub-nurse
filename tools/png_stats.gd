extends SceneTree
## Headless: report basic stats (size, mean luminance, alpha) of a PNG.
## Run: godot --headless --path . --script res://tools/png_stats.gd <path>
## With no argument, checks the surgery backdrop.

func _init() -> void:
	var path := "res://assets/2D/surgery/bg.png"
	var args: Array = OS.get_cmdline_user_args()
	if args.size() > 0:
		path = str(args[0])
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		print("LOAD FAILED: ", path)
		quit(1)
		return
	print("size: ", img.get_size(), " format: ", img.get_format(), " mipmaps: ", img.has_mipmaps())
	var lum_sum: float = 0.0
	var a_sum: float = 0.0
	var n: int = 0
	var bright: int = 0  # pixels with luminance > 0.85
	var step: int = maxi(1, img.get_width() / 200)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			lum_sum += lum
			a_sum += c.a
			if lum > 0.85:
				bright += 1
			n += 1
	print("mean luminance: %.3f   mean alpha: %.3f   bright-pixel ratio: %.3f" % [
		lum_sum / n, a_sum / n, float(bright) / n])
	quit()
