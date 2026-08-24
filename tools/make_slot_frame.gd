extends SceneTree
## One-shot: bake the slot highlight frame (white outline, transparent
## center) into a PNG asset so the scene can reference it directly — no
## runtime texture generation. Run:
##   godot --headless --path . --script res://tools/make_slot_frame.gd

func _init() -> void:
	var w: int = 50
	var h: int = 140  # 1:2.8 aspect — matches the mayo slot footprint 0.05 x 0.14
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var t: int = 3
	img.fill_rect(Rect2i(t, t, w - 2 * t, h - 2 * t), Color(0, 0, 0, 0))
	var err := img.save_png("res://assets/2D/common/slot_frame.png")
	print("saved slot_frame.png err=", err)
	quit()
