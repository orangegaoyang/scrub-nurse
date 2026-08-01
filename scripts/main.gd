extends Node3D
## Main scene: flow control + environment + spawner.

const SLOT_SCENE: PackedScene = preload("res://scenes/table_slot.tscn")
const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

const SLOT_X_POSITIONS: Array[float] = [-0.32, -0.19, -0.06, 0.06, 0.19, 0.32]

@onready var player: CharacterBody3D = $Player
@onready var mayo: Node3D = $MayoStand
@onready var slots_parent: Node3D = $MayoStand/SlotsParent
@onready var instruments_parent: Node3D = $MayoStand/InstrumentsParent
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	_spawn_slots()
	_spawn_instruments()
	player.interact_pressed.connect(_on_interact)
	camera.look_at(Vector3(0.0, 0.4, 0.0))


func _spawn_slots() -> void:
	for i in range(SLOT_X_POSITIONS.size()):
		var slot: Area3D = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slots_parent.add_child(slot)
		slot.position = Vector3(SLOT_X_POSITIONS[i], 0, 0)


func _spawn_instruments() -> void:
	# 3D instruments laid across (rotated 90°) in two rows on the lower part
	# of the table; the upper part is left for the slots.
	var ids: Array = ProcedureData.demand_sequence.duplicate()
	ids.shuffle()
	var xs: Array[float] = [-0.22, 0.0, 0.22]
	var zs: Array[float] = [-0.30, -0.20]
	for i in range(ids.size()):
		var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
		instruments_parent.add_child(inst)
		inst.setup(ids[i])
		inst.position = Vector3(xs[i % 3], 0.0, zs[i / 3])
		inst.rotation_degrees.y = 90.0 + randf_range(-8.0, 8.0)


func _on_interact(_target: Node) -> void:
	pass  # prep interaction (pick/place) handled by pickup_system


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameState.Phase.SURGERY:
			pass
		GameState.Phase.RESULT:
			pass
