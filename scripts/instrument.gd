class_name Instrument
extends RigidBody3D
## A single surgical instrument, shown as a flat card (colour + name). Keeps the
## RigidBody/collision so the existing pickup/place/deliver logic still works.

enum State { IN_TRAY, HELD, IN_SLOT, IN_SURGEON }

const CARD_FONT := preload("res://assets/fonts/ArialUnicode.ttf")
const CARD_W := 0.09
const CARD_H := 0.002
const CARD_D := 0.13

@export var instrument_id: String = ""
var def  # ProcedureData.InstrumentDef (untyped to access inner class fields)
var state: int = State.IN_TRAY

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $NameLabel


func setup(p_id: String) -> void:
	instrument_id = p_id
	def = ProcedureData.get_instrument(p_id)
	if def == null:
		push_error("Instrument: unknown id %s" % p_id)
		return
	label.text = def.name_cn
	label.visible = false
	freeze = true  # no physics simulation
	_apply_card()


func _apply_card() -> void:
	# Hide the placeholder box; build a flat coloured card with the name on top.
	mesh.visible = false
	var card := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CARD_W, CARD_H, CARD_D)
	card.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color
	mat.roughness = 0.7
	card.material_override = mat
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)

	var lbl := Label3D.new()
	lbl.text = def.name_cn
	lbl.set("theme_override_fonts/font", CARD_FONT)
	lbl.font_size = 40
	lbl.pixel_size = 0.0006
	lbl.modulate = Color(0.1, 0.1, 0.1)
	lbl.outline_modulate = Color(1, 1, 1, 1)
	lbl.outline_size = 5
	lbl.no_depth_test = true
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.position = Vector3(0, CARD_H, 0)
	card.add_child(lbl)


func set_state(s: int) -> void:
	state = s
	match s:
		State.HELD:
			label.visible = false
		_:
			label.visible = false


func show_name(v: bool) -> void:
	if state != State.HELD:
		label.visible = v


func play_reject() -> void:
	## Spring scale punch to convey "rejected / bounce back" feedback.
	scale = Vector3.ONE
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.18, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE * 0.92, 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.10).set_ease(Tween.EASE_OUT)
