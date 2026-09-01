extends CharacterBody3D
## Player: fixed-camera interaction source. No walking / mouse-look. Provides
## intent-specific cursor queries so e.g. picking up hits instruments (not the
## slot areas that overlap them), placing hits slots, delivery hits the hand.

const REACH: float = 15.0
const HOLD_Y: float = 1.2  # surgery/tidy hold plane (above the mayo, near the hand)
const PREP_HOLD_Y: float = 2.3  # prep hold plane (raise the held instrument higher/closer to camera)

signal interact_pressed(target: Node)
signal inspect_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed.emit(get_cursor_collider())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		inspect_pressed.emit()


func _ray(mask: int, areas: bool, bodies: bool) -> Dictionary:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mp: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mp)
	var to: Vector3 = from + cam.project_ray_normal(mp) * REACH
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = mask
	q.collide_with_areas = areas
	q.collide_with_bodies = bodies
	return space.intersect_ray(q)


func get_cursor_collider() -> Node:
	# General: instruments (1) + slots/pack (2) + surgeon hand (4); not the table (8).
	return _ray(7, true, true).get("collider", null)


func get_cursor_instrument() -> Node:
	# Bodies only on layer 1 -> ignores slot/hand areas and the table.
	return _ray(1, false, true).get("collider", null)


func get_cursor_slot() -> Node:
	# Slot / pack areas on layer 2.
	return _ray(2, true, false).get("collider", null)


func get_cursor_hand() -> Node:
	# Surgeon hand area on layer 4.
	return _ray(4, true, false).get("collider", null)


func get_cursor_tray_point() -> Vector3:
	# Where the cursor hits the MAYO tray surface (layer 8). Returns
	# Vector3.INF when the cursor is over anything else (the back table's
	# own collision is ignored by name).
	var hit: Dictionary = _ray(8, false, true)
	var collider: Node = hit.get("collider")
	if collider != null and collider.name == "TrayCollision":
		return hit["position"]
	return Vector3.INF


func get_cursor_point() -> Vector3:
	# A held instrument follows the cursor on a horizontal plane. Prep uses a
	# lower plane (top-down view, tables right below); surgery/tidy uses the
	# higher one (the surgeon's hand lives at 1.22).
	var cam: Camera3D = get_viewport().get_camera_3d()
	var mp: Vector2 = get_viewport().get_mouse_position()
	var o: Vector3 = cam.project_ray_origin(mp)
	var d: Vector3 = cam.project_ray_normal(mp)
	var hold_y: float = PREP_HOLD_Y if GameState.current_phase == GameState.Phase.PREP else HOLD_Y
	if abs(d.y) < 0.001:
		return o + d * 1.5
	var t: float = (hold_y - o.y) / d.y
	return o + d * t
