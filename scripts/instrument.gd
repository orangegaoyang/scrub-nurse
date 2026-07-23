class_name Instrument
extends RigidBody3D
## A single surgical instrument. Metadata loaded from ProcedureData.

enum State { IN_TRAY, HELD, IN_SLOT, IN_SURGEON }

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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color
	mesh.material_override = mat
	label.text = def.name_cn
	label.visible = false
	freeze = true  # no physics simulation for MVP


func set_state(s: int) -> void:
	state = s
	match s:
		State.HELD:
			label.visible = true
		_:
			label.visible = false


func show_name(v: bool) -> void:
	if state != State.HELD:
		label.visible = v
