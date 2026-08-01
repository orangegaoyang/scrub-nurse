class_name Instrument
extends RigidBody3D
## A single surgical instrument. Metadata loaded from ProcedureData.

enum State { IN_TRAY, HELD, IN_SLOT, IN_SURGEON }

# Per-id 3D models (Blender-generated GLB). Ids not listed fall back to the
# coloured box mesh so unmodelled instruments still work.
const MODELS: Dictionary = {
	"scalpel": preload("res://assets/models/scalpel.glb"),
	"hemostat": preload("res://assets/models/hemostat.glb"),
	"forceps": preload("res://assets/models/forceps.glb"),
	"scissors": preload("res://assets/models/scissors.glb"),
	"needle_holder": preload("res://assets/models/needle_holder.glb"),
	"gauze": preload("res://assets/models/Gauze.glb"),
}
const DEFAULT_MODEL_SCALE := Vector3(0.5, 0.5, 0.5)
# Per-id overrides (non-uniform allowed) since each GLB was modeled at a
# different native size.
const MODEL_SCALE: Dictionary = {
}

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
	# setup() runs right after add_child, before _ready() fires, so the
	# @onready vars are still null here — fetch the nodes explicitly.
	mesh = $MeshInstance3D
	label = $NameLabel
	label.text = def.name_cn
	label.visible = false
	freeze = true  # no physics simulation
	_apply_model()


func _apply_model() -> void:
	if MODELS.has(instrument_id):
		# Use the real 3D model; hide the placeholder box.
		mesh.visible = false
		var model: Node3D = MODELS[instrument_id].instantiate()
		model.scale = MODEL_SCALE.get(instrument_id, DEFAULT_MODEL_SCALE)
		add_child(model)
	else:
		# Fallback: coloured box.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.color
		mesh.material_override = mat


func set_state(s: int) -> void:
	state = s
	match s:
		State.HELD:
			label.visible = false  # name+purpose shown on the HUD card instead
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
