extends Node
## 手术系统：把医生线和护士线接到一起。医生线管需求节奏，护士线管拿起/放回。

var held_instrument: Instrument = null

var _player: CharacterBody3D
var _surgeon: Surgeon
var _zone: NeutralZone
var _held_parent: Node3D
var _back_zones_parent: Node3D

var _line: SurgeonLine
var _nurse: NurseActions
var _deliver_triggered := false


func _ready() -> void:
	_player = get_parent().get_node("Player")
	_held_parent = get_parent().get_node("HeldParent")
	_surgeon = get_parent().get_node_or_null("Surgeon")
	_zone = get_parent().get_node_or_null("MayoStand/NeutralZone")
	_back_zones_parent = get_parent().get_node_or_null("Backtable/BackTableZones")
	var mayo: Node3D = get_parent().get_node("MayoStand")
	_line = SurgeonLine.new(self, _surgeon, _zone)
	_nurse = NurseActions.new(self, _player, _surgeon, _zone, mayo, _held_parent,
		_back_zones_parent)
	_player.interact_pressed.connect(_on_interact)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.surgeon_line_start.connect(_line.on_line_start)
	if _surgeon != null:
		_surgeon.zone = _zone
		_surgeon.instrument_deposited.connect(_line.on_deposited)
	if _zone != null:
		_zone.zone_freed.connect(_line.on_zone_freed)


func _process(_delta: float) -> void:
	if _surgeon == null:
		return
	var phase: int = GameState.current_phase
	if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
		return
	if held_instrument != null:
		held_instrument.global_position = _player.get_cursor_point() + Vector3(0, 0.05, 0)
		if phase == GameState.Phase.SURGERY:
			_check_delivery()
		_update_highlights()
	else:
		_hide_all_highlights()


func _on_phase_changed(new_phase: int) -> void:
	if _surgeon == null:
		return
	if new_phase == GameState.Phase.SURGERY:
		_line.on_surgery_start()
		_nurse.on_surgery_start()
	elif new_phase == GameState.Phase.TIDY:
		_line.on_tidy_start()


func _on_interact(_target: Node) -> void:
	var phase: int = GameState.current_phase
	if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
		return
	if held_instrument == null:
		var inst := _player.get_cursor_instrument() as Instrument
		if inst != null:
			if inst.state == Instrument.State.IN_SURGEON and _surgeon.is_returning() \
					and inst == _surgeon.held_instrument:
				_take_back(inst)
				return
			match inst.state:
				Instrument.State.IN_SLOT, Instrument.State.IN_ZONE, \
						Instrument.State.ON_MAYO:
					_pick_up(inst)
	else:
		var hit: Node = _player.get_cursor_slot()
		if hit is BackZone:
			_place_in_zone(hit as BackZone)
			return
		if hit is TableSlot and not hit.occupied:
			_place_in_slot(hit as TableSlot)
			return
		if ProcedureData.surgery_free_mayo():
			var tray_point: Vector3 = _player.get_cursor_tray_point()
			if tray_point != Vector3.INF:
				_place_on_mayo(tray_point)


# ---------------- 医生线入口 ----------------

func _check_delivery() -> void:
	if _surgeon == null or held_instrument == null or not _surgeon.is_demanding() \
			or _deliver_triggered:
		return
	if _player.get_cursor_hand() == _surgeon.get_hand_area():
		_deliver_triggered = true
		_deliver(held_instrument)


func _deliver(inst: Instrument) -> void:
	if _line.deliver(inst):
		held_instrument = null
		_nurse.note_delivered()
	else:
		inst.play_reject()


func schedule_after_return() -> void:
	_line.schedule_after_return()


func count_back_table() -> int:
	return _nurse.count_back_table()


# ---------------- 护士线转发（smoke_test 也走这里） ----------------

func _pick_up(inst: Instrument) -> void:
	_nurse.pick_up(inst)


func _take_back(inst: Instrument) -> void:
	_nurse.take_back(inst)


func _place_in_slot(slot: TableSlot) -> void:
	_nurse.place_in_slot(slot)


func _place_on_mayo(point: Vector3) -> void:
	_nurse.place_on_mayo(point)


func _place_in_zone(bzone: BackZone) -> void:
	_nurse.place_in_zone(bzone)


# ---------------- 放置高亮 ----------------

func _update_highlights() -> void:
	if held_instrument == null or _back_zones_parent == null:
		return
	for c in _back_zones_parent.get_children():
		var bz := c as BackZone
		if bz == null:
			continue
		if not bz.is_full() and bz.can_accept(held_instrument):
			bz.show_place_highlight()
		else:
			bz.hide_highlight()


func _hide_all_highlights() -> void:
	if _back_zones_parent == null:
		return
	for c in _back_zones_parent.get_children():
		if c is BackZone:
			(c as BackZone).hide_highlight()
