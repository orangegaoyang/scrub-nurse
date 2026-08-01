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
	camera.look_at(Vector3(0.0, 1.45, 0.0))


func _spawn_slots() -> void:
	for i in range(SLOT_X_POSITIONS.size()):
		var slot: Area3D = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slots_parent.add_child(slot)
		slot.position = Vector3(SLOT_X_POSITIONS[i], 0, 0)


func _spawn_instruments() -> void:
	# Drop all instruments into the tray as a random pile, without the
	# tumbling/jitter a free drop causes: lock each body to vertical-only
	# motion + no rotation, zero bounce. A small random height stagger helps
	# the solver stack overlapping ones into flat layers.
	var ids: Array = ProcedureData.demand_sequence.duplicate()
	ids.shuffle()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 1.0
	for id in ids:
		var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
		instruments_parent.add_child(inst)
		inst.setup(id)
		inst.position = Vector3(randf_range(-0.2, 0.2), 0.12 + randf_range(0.0, 0.1), randf_range(-0.05, 0.0))
		inst.rotation_degrees = Vector3(0, 90.0 + randf_range(-0.5, 0.5), 0)
		inst.physics_material_override = mat
		_lock_for_drop(inst)
		inst.freeze = false
	# Let them settle into a pile, then freeze and release the locks.
	await get_tree().create_timer(0.5).timeout
	for inst in instruments_parent.get_children():
		if inst is Instrument:
			inst.freeze = true
			_unlock_drop(inst)


func _lock_for_drop(inst: RigidBody3D) -> void:
	inst.axis_lock_linear_x = true
	inst.axis_lock_linear_z = true
	inst.axis_lock_angular_x = true
	inst.axis_lock_angular_y = true
	inst.axis_lock_angular_z = true


func _unlock_drop(inst: RigidBody3D) -> void:
	inst.axis_lock_linear_x = false
	inst.axis_lock_linear_z = false
	inst.axis_lock_angular_x = false
	inst.axis_lock_angular_y = false
	inst.axis_lock_angular_z = false


func _on_interact(_target: Node) -> void:
	pass  # prep interaction (pick/place) handled by pickup_system


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameState.Phase.SURGERY:
			pass
		GameState.Phase.RESULT:
			pass
