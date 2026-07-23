extends Node3D
## Main scene: flow control + environment + spawner.

const SLOT_SCENE: PackedScene = preload("res://scenes/table_slot.tscn")
const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

const SLOT_X_POSITIONS: Array[float] = [-1.0, -0.6, -0.2, 0.2, 0.6, 1.0]

@onready var player: CharacterBody3D = $Player
@onready var table: Node3D = $Table
@onready var slots_parent: Node3D = $Table/SlotsParent
@onready var tray_parent: Node3D = $Table/TrayParent
@onready var prep_card: Control = $UI/PrepCard
@onready var countdown: Control = $UI/Countdown


func _ready() -> void:
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	_spawn_slots()
	_spawn_tray_instruments()


func _spawn_slots() -> void:
	for i in range(SLOT_X_POSITIONS.size()):
		var slot: Area3D = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slots_parent.add_child(slot)
		slot.position = Vector3(SLOT_X_POSITIONS[i], 0, 0)


func _spawn_tray_instruments() -> void:
	var ids: Array = ProcedureData.demand_sequence.duplicate()
	ids.shuffle()
	var xs: Array[float] = [-0.8, -0.48, -0.16, 0.16, 0.48, 0.8]
	xs.shuffle()
	for i in range(ids.size()):
		var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
		tray_parent.add_child(inst)
		inst.setup(ids[i])
		inst.position = Vector3(xs[i], 0.03, randf_range(-0.12, 0.12))
		inst.rotation_degrees.y = randf_range(-25.0, 25.0)


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		GameState.Phase.COUNTDOWN:
			prep_card.visible = false
			_run_countdown()
		GameState.Phase.SURGERY:
			prep_card.visible = false
		GameState.Phase.RESULT:
			pass


func _run_countdown() -> void:
	countdown.run()
	await countdown.finished
	if GameState.current_phase == GameState.Phase.COUNTDOWN:
		GameState.start_surgery()
