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
	_camera = CameraDirector.new($CameraPrep, $CameraMayo, $CameraBackTable,
		mayo, $NeutralZone, surgeon, voice, $DirectorMarkers)
	_camera.prepare()
	_layout = MayoLayout.new($MayoStand/SlotsParent, back_table, back_zones_parent, mayo)
	# 卡通统一着色:房间、手、器械台、mayo 车全部换 toon 材质(器械在
	# instrument.gd 里自己换)。
	Util.apply_toon(room)
	Util.apply_toon(surgeon.get_node("HandPivot/HandModel"))
	Util.apply_toon($Backtable/BackTableVisual)
	Util.apply_toon(mayo.get_node("MayoVisual"))
	# 暖色基调 + 参考图配色:背台面成青色软垫感,mayo 暖象牙白,房间去冷灰。
	Util.tint_toon(room, Color(0.9, 0.88, 0.86))
	Util.tint_toon($Backtable/BackTableVisual, Color(0.52, 0.82, 0.8))
	Util.tint_toon(mayo.get_node("MayoVisual"), Color(0.94, 0.9, 0.82))
	ui.visible = true
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	$NeutralZone.visible = false
	surgeon.visible = false
	_layout.apply_guidance_tier()
	_layout.apply_back_table_visibility()
	if ProcedureData.has_back_table():
		for c in back_zones_parent.get_children():
			if c is BackZone:
				(c as BackZone).set_dimmed(false)
	var spawner := InstrumentSpawner.new($Backtable/BackTableInstruments)
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
