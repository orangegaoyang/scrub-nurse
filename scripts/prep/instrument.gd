class_name Instrument
extends RigidBody3D
## A single surgical instrument. Metadata loaded from ProcedureData.

enum State { IN_TRAY, HELD, IN_SLOT, IN_SURGEON, IN_ZONE, ON_MAYO }

# Per-id 3D models (Blender-generated GLB). Ids not listed fall back to the
# coloured box mesh so unmodelled instruments still work.
const MODELS: Dictionary = {
	"scalpel": preload("res://assets/models/instruments/scalpel.glb"),
	"hemostat": preload("res://assets/models/instruments/hemostat.glb"),
	"forceps": preload("res://assets/models/instruments/forceps.glb"),
	"scissors": preload("res://assets/models/instruments/scissors.glb"),
	"needle_holder": preload("res://assets/models/instruments/needle_holder.glb"),
	"gauze": preload("res://assets/models/instruments/gauze.glb"),
}

# 所有器械共用的材质（assets/material/instrument_material_3d.tres，银色金属）。
# 真实模型与备用盒体都强制用它，保证观感统一。
const INSTRUMENT_MATERIAL := preload("res://assets/material/instrument_material_3d.tres")

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
		#model.scale = DEFAULT_MODEL_SCALE
		add_child(model)
		_fit_collision(model)
		# 纱布（gauze）保留它自己的材质（无菌纱布观感），其余器械强制共享材质。
		if instrument_id != "gauze":
			_apply_shared_material(model)
	else:
		# Fallback: box，同样用共享材质，与其它器械观感一致。
		mesh.material_override = INSTRUMENT_MATERIAL


func _apply_shared_material(node: Node) -> void:
	## 把共享材质打到子树里每一个 MeshInstance3D 上（覆盖该网格面片自身的材质）。
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			mi.material_override = INSTRUMENT_MATERIAL
	for c in node.get_children():
		_apply_shared_material(c)


func _fit_collision(model: Node3D) -> void:
	# 把碰撞盒改成和真实模型一样大、一样位置，这样点击判定区（射线捡取）才和看
	# 到的模型对得上。器械都被 freeze，碰撞盒只用来做 raycast。glb 都是单节点单
	# 网格；万一 Godot 包了一层 Node3D，就取第一个 MeshInstance3D。
	var mi := model as MeshInstance3D
	if mi == null:
		for c in model.get_children():
			if c is MeshInstance3D:
				mi = c
				break
	if mi == null:
		return
	var aabb := mi.get_aabb()   # 模型无变换，局部 AABB 即真实包围盒
	if aabb.size.length() < 0.001:
		return
	var box := BoxShape3D.new()
	box.size = aabb.size
	var col: CollisionShape3D = $CollisionShape3D
	col.shape = box
	col.position = aabb.get_center()


func set_state(s: int) -> void:
	state = s
	label.visible = false


func play_reject() -> void:
	## Spring scale punch to convey "rejected / bounce back" feedback.
	scale = Vector3.ONE
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.18, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE * 0.92, 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.10).set_ease(Tween.EASE_OUT)
