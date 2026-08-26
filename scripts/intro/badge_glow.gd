class_name BadgeGlow
extends Node
## Glow affordances for the intro badge, split off from intro_badge.gd.
## Owns the first-open hint glow around the badge (fade in once it has rested,
## breathe, hover flare, dismiss forever on pickup) and the drop-target slot
## glow shown while the badge is dragged. The badge script only triggers
## events; this component owns every tween, material and cursor change.

const GLOW_DELAY := 2.0  # seconds of rest before the badge glow fades in
const GLOW_FADE_IN := 0.8
const GLOW_BREATHE := 1.5  # seconds per full breath
const GLOW_LOW := 0.25
const GLOW_HIGH := 0.5
const GLOW_HOVER := 0.7  # one-shot flare when the cursor is over the badge
const GLOW_DISMISS := 0.2
const SLOT_GLOW_LOW := 0.35  # drop-target glow breathing while the badge is held
const SLOT_GLOW_HIGH := 0.6

var _hint: MeshInstance3D
var _hint_mat: ShaderMaterial
var _slot: MeshInstance3D
var _slot_mat: ShaderMaterial
var _dismissed: bool = false
var _breath: Tween
var _flare: Tween
var _slot_tw: Tween


func setup(hint: MeshInstance3D, slot: MeshInstance3D) -> void:
	_hint = hint
	_hint_mat = hint.material_override
	_slot = slot
	_slot_mat = slot.material_override
	_hint.visible = false
	_slot.visible = false


# ---------------- Badge hint glow ----------------

func show_when_rested() -> void:
	# First-open affordance: once the badge has rested on the table for a
	# beat, a soft glow breathes around its edge — "this card can be picked
	# up". Replays skip this entirely (the badge is already in the slot).
	await Util.wait(GLOW_DELAY)
	if _dismissed:
		return  # player already picked the badge up while the wait ran
	_hint.visible = true
	_hint_mat.set_shader_parameter("alpha", 0.0)
	var fade := create_tween()
	fade.tween_property(_hint_mat, "shader_parameter/alpha", GLOW_LOW, GLOW_FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished
	if _dismissed:
		return
	_breathe()


func flare() -> void:
	# Hover confirmation: the glow flares once and the cursor becomes a hand.
	if not _hint.visible or _dismissed:
		return
	_kill_flare()
	if _breath:
		_breath.kill()
		_breath = null
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_flare = create_tween()
	_flare.tween_property(_hint_mat, "shader_parameter/alpha", GLOW_HOVER, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func settle() -> void:
	if not _hint.visible or _dismissed:
		return
	_kill_flare()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_flare = create_tween()
	_flare.tween_property(_hint_mat, "shader_parameter/alpha", GLOW_LOW, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flare.finished.connect(_breathe)


func dismiss() -> void:
	# Picked up: the hint has done its job — fade it out for good.
	_dismissed = true
	_kill_flare()
	if _breath:
		_breath.kill()
		_breath = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not _hint.visible:
		return
	var tw := create_tween()
	tw.tween_property(_hint_mat, "shader_parameter/alpha", 0.0, GLOW_DISMISS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _hint.visible = false)


func _breathe() -> void:
	if _breath:
		_breath.kill()
	_breath = create_tween().set_loops()
	_breath.tween_property(_hint_mat, "shader_parameter/alpha", GLOW_HIGH, GLOW_BREATHE * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_hint_mat, "shader_parameter/alpha", GLOW_LOW, GLOW_BREATHE * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_flare() -> void:
	if _flare:
		_flare.kill()
		_flare = null


# ---------------- Slot glow ----------------

func slot_on() -> void:
	slot_off()
	_slot.visible = true
	_slot_mat.set_shader_parameter("alpha", SLOT_GLOW_LOW)
	_slot_tw = create_tween().set_loops()
	_slot_tw.tween_property(_slot_mat, "shader_parameter/alpha", SLOT_GLOW_HIGH, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_tw.tween_property(_slot_mat, "shader_parameter/alpha", SLOT_GLOW_LOW, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func slot_off() -> void:
	if _slot_tw:
		_slot.visible = false
		_slot_tw.kill()
		_slot_tw = null
	if _slot_mat:
		_slot_mat.set_shader_parameter("alpha", 0.0)
