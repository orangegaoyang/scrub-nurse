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
		_fit_collision(model)
	else:
		# Fallback: coloured box.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.color
		mesh.material_override = mat


func _fit_collision(model: Node3D) -> void:
	# Size the collision box to the model's real bounding box (in this
	# instrument's local space) so each instrument's click area matches its
	# own model. Instruments are frozen, so this only affects raycasts.
	var aabb := _subtree_aabb(model, Transform3D.IDENTITY)
	if aabb.size.length() < 0.001:
		return
	var box := BoxShape3D.new()
	box.size = aabb.size
	var col: CollisionShape3D = $CollisionShape3D
	col.shape = box
	col.position = aabb.get_center()


func _subtree_aabb(node: Node3D, parent_xform: Transform3D) -> AABB:
	var self_xform: Transform3D = parent_xform * node.transform
	var result := AABB()
	var has := false
	if node is MeshInstance3D:
		var m := node as MeshInstance3D
		var transformed := _xform_aabb(m.get_aabb(), self_xform)
		if transformed.size.length() > 0.001:
			result = transformed
			has = true
	for c in node.get_children():
		if c is Node3D:
			var c_aabb := _subtree_aabb(c, self_xform)
			if c_aabb.size.length() > 0.001:
				if has:
					result = result.merge(c_aabb)
				else:
					result = c_aabb
					has = true
	return result


func _xform_aabb(a: AABB, x: Transform3D) -> AABB:
	var p := a.position
	var e := a.end
	var pts: Array[Vector3] = [
		x * Vector3(p.x, p.y, p.z),
		x * Vector3(e.x, p.y, p.z),
		x * Vector3(p.x, e.y, p.z),
		x * Vector3(e.x, e.y, p.z),
		x * Vector3(p.x, p.y, e.z),
		x * Vector3(e.x, p.y, e.z),
		x * Vector3(p.x, e.y, e.z),
		x * Vector3(e.x, e.y, e.z),
	]
	var out := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		out = out.expand(pts[i])
	return out


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
