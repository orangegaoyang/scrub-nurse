extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var mayo: Node3D = $MayoStand
@onready var back_table: Node3D = $Backtable
@onready var ui: CanvasLayer = $UI
@onready var voice: AudioStreamPlayer = $Voice


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ProcedureData.reload_for_selected()
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	var spawner := InstrumentSpawner.new($Backtable/BackTableInstruments)
	await spawner.spawn()	
	await Transition.fade_in()


func _on_phase_changed()->void:
	pass
