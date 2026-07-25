extends Node3D
## Main scene: flow control + environment + spawner.

const SLOT_SCENE: PackedScene = preload("res://scenes/table_slot.tscn")
const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

const SLOT_X_POSITIONS: Array[float] = [-0.6, -0.36, -0.12, 0.12, 0.36, 0.6]

@onready var player: CharacterBody3D = $Player
@onready var mayo: Node3D = $MayoStand
@onready var slots_parent: Node3D = $MayoStand/SlotsParent
@onready var instruments_parent: Node3D = $MayoStand/InstrumentsParent
@onready var pack: Node = $MayoStand/Pack
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	_spawn_slots()
	_spawn_instruments(true)
	player.interact_pressed.connect(_on_interact)
	pack.opened.connect(_on_pack_opened)
	# Fixed angled view: straight on to the Mayo tray (surgeon visible beyond).
	camera.look_at(Vector3(0.415, 0.88, 0.471))


func _spawn_slots() -> void:
	for i in range(SLOT_X_POSITIONS.size()):
		var slot: Area3D = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slots_parent.add_child(slot)
		slot.position = Vector3(SLOT_X_POSITIONS[i], 0, 0)


func _spawn_instruments(hidden: bool) -> void:
	var ids: Array = ProcedureData.demand_sequence.duplicate()
	ids.shuffle()
	var xs: Array[float] = [-0.45, -0.27, -0.09, 0.09, 0.27, 0.45]
	xs.shuffle()
	for i in range(ids.size()):
		var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
		instruments_parent.add_child(inst)
		inst.setup(ids[i])
		inst.position = Vector3(xs[i], 0.02, randf_range(-0.08, 0.08))
		inst.rotation_degrees.y = randf_range(-25.0, 25.0)
		if hidden:
			inst.visible = false
			inst.collision_layer = 0


func _on_interact(target: Node) -> void:
	if GameState.current_phase != GameState.Phase.PREP:
		return
	if not pack.is_opened() and target == pack.get_node("PackArea"):
		pack.open()


func _on_pack_opened() -> void:
	for inst in instruments_parent.get_children():
		if inst is Instrument:
			inst.visible = true
			inst.collision_layer = 1


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameState.Phase.SURGERY:
			pass
		GameState.Phase.RESULT:
			pass
