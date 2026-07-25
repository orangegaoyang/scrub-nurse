extends CharacterBody3D
## Player: fixed-camera interaction source. No walking / mouse-look. Emits the
## object under the cursor when the player clicks, and exposes the cursor's
## 3D point/area for pickup, placement and delivery.

const REACH: float = 6.0

signal interact_pressed(target: Node)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_pressed.emit(get_cursor_collider())


func _cursor_query() -> Dictionary:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mp: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mp)
	var to: Vector3 = from + cam.project_ray_normal(mp) * REACH
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	return space.intersect_ray(q)


func get_cursor_collider() -> Node:
	var res: Dictionary = _cursor_query()
	return res.get("collider", null)


func get_cursor_point() -> Vector3:
	var res: Dictionary = _cursor_query()
	if res.has("position"):
		return res["position"]
	var cam: Camera3D = get_viewport().get_camera_3d()
	var mp: Vector2 = get_viewport().get_mouse_position()
	return cam.project_ray_origin(mp) + cam.project_ray_normal(mp) * 1.5
