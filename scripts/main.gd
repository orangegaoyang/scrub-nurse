extends Node3D
## Main scene: flow control + environment + spawner + camera staging.
##
## Two room setups share one cursor-driven interaction model:
##   PREP    — one wide view showing the back table and the Mayo side by side
##             (no view switching); instruments are scattered on the back
##             table and get organized onto the Mayo.
##   SURGERY — pressing "进入手术" plays the push-turn transition: the Mayo
##             rolls forward to the operating table while the camera turns
##             around; the back table ends up behind the player (Q to look
##             back) and the neutral-zone tray appears at the Mayo's edge.
## Mayo slots vs free cells follow the player's per-procedure guidance tier:
## Level I = 6 hard slots (also used by prep), Level II/III = 8 free cells.

const INSTRUMENT_SCENE: PackedScene = preload("res://scenes/instrument.tscn")

# Mayo positions: prep area (scene-set) -> operating table.
const MAYO_SURGERY_POS := Vector3(0.522, 0.081, 0.073)
const PUSH_ROLL_TIME := 1.0
const DOLLY_TIME := 1.1  # continuous camera walk from prep to the field

const ENTRANCE_TIME := 2.5  # zoom-out reveal, mirrors the intro's push
const ENTRANCE_FOV_FACTOR := 0.55  # 42° → ~23° at the start
const ENTRANCE_DEEP := 0.3  # camera starts this fraction of the way to the tables
const ENTRANCE_VOICE := "surgery_start"  # "Let's get ready." once the room is in view
const ENTRANCE_VOICE_DELAY := 0.4

@onready var player: CharacterBody3D = $Player
@onready var surgeon: Node3D = $Surgeon
@onready var mayo: Node3D = $MayoStand
@onready var zone: Node3D = $MayoStand/NeutralZone
@onready var slots_parent: Node3D = $MayoStand/SlotsParent
@onready var instruments_parent: Node3D = $BackTableInstruments
@onready var back_table: Node3D = $small_backtable
@onready var back_zones_parent: Node3D = $BackTableZones
@onready var camera_prep: Camera3D = $CameraPrep
@onready var camera_mayo: Camera3D = $CameraMayo
@onready var camera_back: Camera3D = $CameraBackTable
@onready var ui: CanvasLayer = $UI
@onready var voice: AudioStreamPlayer = $Voice

var _on_back_view: bool = false
# The mayo camera's rest pose (captured after look_at) — the dolly lands here.
var _mayo_rest_pos := Vector3.ZERO
var _mayo_rest_rot := Vector3.ZERO
var _mayo_rest_fov := 38.2
var _prep_rest_fov := 64.5


func _ready() -> void:
	ProcedureData.reload_for_selected()  # load the schedule-picked procedure
	#camera_prep.look_at(Vector3(0.5, 0.95, 4.5))
	camera_mayo.look_at(Vector3(0.45, 0.98, 0.05))
	camera_back.look_at(Vector3(0.0, 0.95, 4.5))
	_mayo_rest_pos = camera_mayo.position
	_mayo_rest_rot = camera_mayo.rotation_degrees
	_mayo_rest_fov = camera_mayo.fov
	_prep_rest_fov = camera_prep.fov  # the editor-set prep fov, not a constant
	# The editor keeps non-current cameras hidden for decluttering; runtime
	# needs them visible (hiding a camera also hides its backdrop sprite).
	camera_prep.visible = true
	camera_mayo.visible = true
	camera_back.visible = true
	ui.visible = true  # runtime needs the HUD/list/result layer on
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	# Mayo slots and back-table zones are scene content, placed and arranged
	# in the editor; nothing is spawned by code except the instrument pile.
	# Zones start dimmed via their own `dimmed` property (editor-set).
	zone.visible = false  # the neutral zone belongs to surgery, not prep
	surgeon.visible = false  # the hand stays out of the prep view
	_apply_guidance_tier()
	_apply_back_table_visibility()
	if ProcedureData.has_back_table():
		# S3's prep organizes the extra instruments into the zones, so they
		# are lit from the start (no surgery-time reveal needed).
		for c in back_zones_parent.get_children():
			if c is BackZone:
				(c as BackZone).set_dimmed(false)
	_spawn_instruments()
	_entrance_zoom()
	# The corridor's "lights on" flash covers the swap: reveal the room out
	# of the white so it reads as the OR lights settling.
	Transition.fade_in_from_white(0.5)


func _entrance_zoom() -> void:
	# The scene opens deep and tight on the prep tables, then glides back to
	# the idle framing as the black fades.
	var rest_pos := camera_prep.global_position
	var focus := Vector3(0.5, 0.95, 4.5)
	var dir := (focus - rest_pos).normalized()
	var d := rest_pos.distance_to(focus)
	camera_prep.global_position = focus - dir * d * ENTRANCE_DEEP
	camera_prep.fov = _prep_rest_fov * ENTRANCE_FOV_FACTOR
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera_prep, "global_position", rest_pos, ENTRANCE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera_prep, "fov", _prep_rest_fov, ENTRANCE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await Util.wait(ENTRANCE_VOICE_DELAY)
	Util.play_voice(voice, ENTRANCE_VOICE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_view"):
		# View switching only exists once the back table is BEHIND the player
		# (S3 only — S1/S2 have no back table to look at).
		if not ProcedureData.has_back_table():
			return
		var phase: int = GameState.current_phase
		if phase != GameState.Phase.SURGERY and phase != GameState.Phase.TIDY:
			return
		switch_view(not _on_back_view)
		get_viewport().set_input_as_handled()


func switch_view(to_back: bool) -> void:
	if _on_back_view == to_back:
		return
	_on_back_view = to_back
	if to_back:
		camera_back.make_current()
	else:
		camera_mayo.make_current()
	GameState.view_switched.emit()


func _push_transition() -> void:
	## Continuous shot, no fade: the camera starts from the prep pose and
	## walks forward with the cart to the operating table. The mayo camera
	## borrows the prep camera's pose first so the shot never cuts.
	zone.visible = ProcedureData.has_neutral_zone()
	surgeon.visible = true
	if ProcedureData.has_neutral_zone():
		# The neutral zone just appeared — teach its purpose. The HUD hint
		# fades in with the tray and waits for acknowledgment.
		GameState.hint_changed.emit("用过的器械会放进中立区——及时取走清台", true)
	else:
		# S1: no neutral zone, nothing to explain — the surgeon may begin.
		GameState.surgeon_line_start.emit()
	camera_mayo.global_transform = camera_prep.global_transform
	camera_mayo.fov = camera_prep.fov
	camera_mayo.make_current()
	_on_back_view = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera_mayo, "global_position", _mayo_rest_pos, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera_mayo, "rotation_degrees", _mayo_rest_rot, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera_mayo, "fov", _mayo_rest_fov, DOLLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mayo, "global_position", MAYO_SURGERY_POS, PUSH_ROLL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# ---------------- Spawning ----------------

func _spawn_instruments() -> void:
	# Every surgery scatters its instruments on the back table during prep
	# ("the last shift dumped them"): prep = pick each one up and organize it
	# onto the Mayo. Vertical-only drop, no rotation change, zero bounce.
	# Extra instances of multi-count items (gauze spares) are supplies — they
	# start already laid out on the Mayo tray, no prep placement needed.
	var ids: Array = ProcedureData.instrument_order.duplicate()
	ids.shuffle()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.0
	mat.friction = 1.0
	for id in ids:
		var def = ProcedureData.get_instrument(id)
		var count: int = def.count if def != null else 1
		for k in count:
			var inst: RigidBody3D = INSTRUMENT_SCENE.instantiate()
			if k == 0:
				instruments_parent.add_child(inst)
				inst.position = Vector3(
					randf_range(-0.45, 0.45),
					0.04 + randf_range(0.0, 0.04),
					randf_range(-0.22, 0.22))
				inst.setup(id)
				inst.rotation_degrees = Vector3(0, randf_range(0.0, 360.0), 0)
				inst.physics_material_override = mat
				_lock_for_drop(inst)
				inst.freeze = false
			else:
				# Spare instance: lay it on the Mayo tray right away.
				mayo.add_child(inst)
				inst.position = _spare_spot(k)
				inst.setup(id)
				inst.rotation_degrees = Vector3(0.0, 0.0, 0.0)
				inst.set_state(Instrument.State.ON_MAYO)
				inst.collision_layer = 1
				inst.freeze = true
	# Let them settle onto the tabletop, then freeze and release the locks.
	await Util.wait(0.5)
	for inst in instruments_parent.get_children():
		if inst is Instrument:
			inst.freeze = true
			_unlock_drop(inst)


func _spare_spot(k: int) -> Vector3:
	## Mayo-local rest spot for the k-th spare instance of a multi-count item:
	## a neat supply row at the back edge of the tray, clear of the slots.
	var start_x := -0.30
	var step_x := 0.10
	return Vector3(start_x + step_x * (k - 1), 0.92, -0.15)


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


# ---------------- Mayo slots / free tray ----------------

func _apply_guidance_tier() -> void:
	## Slots are shown for the procedure's instrument count. In surgery they
	## stay for S1 (slot returns) and vanish for free-mayo procedures (S2/S3).
	var count: int = ProcedureData.instrument_order.size()
	var in_surgery: bool = GameState.current_phase == GameState.Phase.SURGERY \
		or GameState.current_phase == GameState.Phase.TIDY
	var show: bool = not in_surgery or not ProcedureData.surgery_free_mayo()
	for s in slots_parent.get_children():
		if s is TableSlot:
			var active: bool = show and (s as TableSlot).slot_index < count
			(s as TableSlot).visible = active
			(s as TableSlot).collision_layer = 2 if active else 0


func _apply_back_table_visibility() -> void:
	## The back table is ALWAYS the prep staging surface (instruments scatter
	## there in every surgery). During surgery it stays only for S3 (return
	## judgment + tidy); S1/S2 have no use for it once the operation starts.
	var phase: int = GameState.current_phase
	var in_prep: bool = phase == GameState.Phase.PREP or phase == GameState.Phase.COUNTDOWN
	back_table.visible = in_prep or ProcedureData.has_back_table()
	back_zones_parent.visible = ProcedureData.has_back_table()


func _release_slot_instruments() -> void:
	## Free-mayo procedures start surgery by lifting the prep arrangement off
	## the hidden slots and laying it flat on the tray — the player's prep
	## layout becomes the starting layout. S1 keeps instruments in their slots.
	if not ProcedureData.surgery_free_mayo():
		return
	for s in slots_parent.get_children():
		if s is TableSlot and s.occupied:
			var inst: Instrument = s.current_instrument
			var gp: Vector3 = inst.global_position
			s.occupied = false
			s.current_instrument = null
			s.clear_feedback()
			inst.set_state(Instrument.State.ON_MAYO)
			inst.reparent(mayo)
			var local := mayo.to_local(gp)
			local.y = 0.92
			inst.position = local
			inst.rotation_degrees = Vector3(0.0, 0.0, 0.0)
			inst.collision_layer = 1
			inst.freeze = true


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameState.Phase.SURGERY:
		_apply_guidance_tier()
		_release_slot_instruments()
		_apply_back_table_visibility()
		if _on_back_view:
			switch_view(false)  # surgery opens on the mayo view
		_push_transition()
	elif new_phase == GameState.Phase.TIDY:
		_apply_back_table_visibility()
	elif new_phase == GameState.Phase.RESULT:
		pass
