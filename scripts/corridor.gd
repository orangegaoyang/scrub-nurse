extends Node3D
## Corridor transition: the mayo is wheeled down a hall toward the OR — a
## top-down floor strip scrolls beneath the mayo while it bobs, then we fade
## into the surgery (main) scene. Uses
## res://assets/2D/transition/corridor.png if present, else a generated tile
## placeholder so the scroll is visible immediately. Drop the real strip in
## later and it upgrades automatically.

const CORRIDOR_IMG := "res://assets/2D/transition/corridor.png"
const DURATION := 3.0
const SCROLL_SPEED := 0.6  # UV offset units per second (negate to flip direction)

@onready var camera: Camera3D = $Camera3D
@onready var floor_mesh: MeshInstance3D = $Camera3D/Floor
@onready var mayo: MeshInstance3D = $Mayo

var _t: float = 0.0
var _mayo_y: float
var _floor_mat: StandardMaterial3D


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.45, 0.0))
	_mayo_y = mayo.position.y
	_floor_mat = floor_mesh.material_override
	_floor_mat.albedo_texture = _resolve_texture()
	_bob()
	await Transition.fade_in()
	get_tree().create_timer(DURATION).timeout.connect(_proceed)


func _process(delta: float) -> void:
	_t += delta
	# Scroll the floor downward to read as forward motion.
	_floor_mat.uv1_offset.y = _t * SCROLL_SPEED


func _bob() -> void:
	# Gentle push-bob on the mayo as it's wheeled along.
	var tw := create_tween().set_loops()
	tw.tween_property(mayo, "position:y", _mayo_y + 0.012, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mayo, "position:y", _mayo_y - 0.012, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mayo, "position:y", _mayo_y, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _resolve_texture() -> Texture2D:
	if ResourceLoader.exists(CORRIDOR_IMG):
		var t = load(CORRIDOR_IMG)
		if t is Texture2D:
			return t
	return _make_placeholder()


func _make_placeholder() -> Texture2D:
	# A simple tile grid so the scroll is visible before corridor.png is added.
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.80, 0.82, 0.80))
	var line := Color(0.55, 0.58, 0.55)
	for i in range(0, s, 32):
		for x in range(s):
			img.set_pixel(x, i, line)
			img.set_pixel(i, x, line)
	return ImageTexture.create_from_image(img)


func _proceed() -> void:
	set_process(false)
	await Transition.fade_out()
	await Util.wait(1.0)  # hold on black a beat
	get_tree().change_scene_to_file("res://scenes/main.tscn")
