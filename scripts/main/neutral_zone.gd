class_name NeutralZone
extends Node3D
## Neutral-zone tray on the patient-side edge of the Mayo stand. The surgeon
## deposits used instruments here (without handing them back directly) and the
## nurse collects them at her own pace. Capacity 3 — when full, the surgeon
## waits with the instrument in hand (back-pressure valve).

signal zone_freed()

@export var capacity: int = 3
@export var place_state: int = Instrument.State.IN_ZONE

@onready var anchors_parent: Node3D = $Anchors
@onready var tray_mesh: MeshInstance3D = get_node_or_null("TrayMesh")

var _anchor_list: Array[Node3D] = []
var _glow_tw: Tween = null


func _ready() -> void:
	for c in anchors_parent.get_children():
		if c is Node3D:
			_anchor_list.append(c)


func place_instrument(inst: Instrument) -> Node3D:
	## Reparent `inst` into a free anchor slot; returns the anchor or null
	## when full.
	for anchor in _anchor_list:
		if anchor.get_child_count() == 0:
			inst.set_state(place_state)
			inst.reparent(anchor)
			inst.transform = Transform3D.IDENTITY
			inst.position = Vector3(0, 0.02, 0)
			inst.collision_layer = 1
			inst.freeze = true
			_refresh_glow()
			return anchor
	return null


func collected() -> void:
	## The nurse collected an instrument (already reparented out). Tell
	## listeners so the surgery system can retry a waiting surgeon deposit.
	zone_freed.emit()
	_refresh_glow()


func count() -> int:
	var n: int = 0
	for anchor in _anchor_list:
		if anchor.get_child_count() > 0:
			n += 1
	return n


func is_full() -> bool:
	return count() >= capacity


# ---------------- Non-empty breathing glow ----------------

func _refresh_glow() -> void:
	## The tray breathes with a soft glow whenever it holds instruments —
	## the affordance that says "there is something here for you".
	if tray_mesh == null:
		return
	if count() > 0:
		if _glow_tw == null or not _glow_tw.is_valid():
			_start_glow()
	else:
		_stop_glow()


func _start_glow() -> void:
	var mat: StandardMaterial3D = tray_mesh.get_surface_override_material(0)
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.35
	_glow_tw = create_tween().set_loops()
	_glow_tw.tween_property(mat, "emission_energy_multiplier", 1.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tw.tween_property(mat, "emission_energy_multiplier", 0.35, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_glow() -> void:
	if _glow_tw != null and _glow_tw.is_valid():
		_glow_tw.kill()
	_glow_tw = null
	if tray_mesh == null:
		return
	var mat: StandardMaterial3D = tray_mesh.get_surface_override_material(0)
	if mat != null:
		mat.emission_enabled = false
