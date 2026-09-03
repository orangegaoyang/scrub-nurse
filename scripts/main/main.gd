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
	var direct := GameState.enter_surgery_direct
	GameState.enter_surgery_direct = false
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
	if direct:
		# Hand-off from the prep check-list: instruments are already organized,
		# so seat them into their mayo/back slots and start the surgery phase
		# (the phase handler reveals the surgeon + dollies the mayo in).
		_seat_instruments()
		GameState.start_surgery()
	else:
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


func _seat_instruments() -> void:
	## Hand-off entry from the prep check-list: the instruments were already
	## organized, so seat each one into its Mayo slot (slot_index < 6) or
	## back-table category zone (>= 6). Free-Mayo procedures get their slot
	## items laid onto the tray by release_slot_instruments() during the
	## SURGERY phase change.
	var slots: Array[TableSlot] = []
	for c in $MayoStand/SlotsParent.get_children():
		if c is TableSlot:
			slots.append(c)
	var zones: Array[BackZone] = []
	for c in back_zones_parent.get_children():
		if c is BackZone:
			zones.append(c)
	var spawned: Array[Node] = $Backtable/BackTableInstruments.get_children()
	for n in spawned:
		var inst := n as Instrument
		if inst == null or inst.def == null:
			continue
		var idx: int = inst.def.slot_index
		if idx < 6:
			var target: TableSlot = null
			for s in slots:
				if s.slot_index == idx:
					target = s
					break
			if target == null:
				continue
			inst.set_state(Instrument.State.IN_SLOT)
			inst.reparent(target)
			inst.position = Vector3(0, 0.01, 0)
			inst.rotation_degrees = Vector3(0, 90, 0)
			inst.collision_layer = 1
			inst.freeze = true
			target.occupied = true
			target.current_instrument = inst
		else:
			var bz: BackZone = null
			for z in zones:
				if z.category == inst.def.category:
					bz = z
					break
			if bz != null:
				bz.place_instrument(inst)
				inst.collision_layer = 1
