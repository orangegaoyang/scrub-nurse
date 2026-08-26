extends Node3D
## 主场景：阶段流程 + 环境适配 + 相机调度 + 器械生成。

@onready var player: CharacterBody3D = $Player
@onready var surgeon: Node3D = $Surgeon
@onready var room: Node3D = $Room
@onready var mayo: Node3D = $MayoStand
@onready var back_table: Node3D = $Backtable/BackTableVisual/backtable
@onready var back_zones_parent: Node3D = $Backtable/BackTableZones
@onready var ui: CanvasLayer = $UI
@onready var voice: AudioStreamPlayer = $Voice

var _camera: CameraDirector
var _layout: MayoLayout


func _ready() -> void:
	ProcedureData.reload_for_selected()
	RoomSetup.apply(room, $Backtable/BackTableVisual)
	_camera = CameraDirector.new($CameraPrep, $CameraMayo, $CameraBackTable,
		mayo, $MayoStand/NeutralZone, surgeon, voice)
	_camera.prepare()
	_layout = MayoLayout.new($MayoStand/SlotsParent, back_table, back_zones_parent, mayo)
	ui.visible = true
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	$MayoStand/NeutralZone.visible = false
	surgeon.visible = false
	_layout.apply_guidance_tier()
	_layout.apply_back_table_visibility()
	if ProcedureData.has_back_table():
		for c in back_zones_parent.get_children():
			if c is BackZone:
				(c as BackZone).set_dimmed(false)
	var spawner := InstrumentSpawner.new($Backtable/BackTableInstruments, mayo)
	await spawner.spawn()
	await _camera.entrance_zoom()
	Transition.fade_in_from_white(0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_view"):
		if not ProcedureData.has_back_table():
			return
		var phase: int = GameState.current_phase
		if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
			return
		_camera.toggle_view()
		get_viewport().set_input_as_handled()


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.SURGERY:
		_layout.apply_guidance_tier()
		_layout.release_slot_instruments()
		_layout.apply_back_table_visibility()
		if _camera.is_on_back_view():
			_camera.show_mayo_view()
		_camera.push_transition()
	elif new_phase == GameState.Phase.TIDY:
		_layout.apply_back_table_visibility()
