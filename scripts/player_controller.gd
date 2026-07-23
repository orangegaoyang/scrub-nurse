extends CharacterBody3D
## First-person player: free cursor + right-drag look + cursor-ray interaction.

const MOUSE_SENSITIVITY: float = 0.0025
const PITCH_LIMIT: float = deg_to_rad(80.0)
const MOVE_SPEED: float = 3.0
const REACH: float = 4.0

@onready var camera: Camera3D = $Camera3D

var _dragging_look: bool = false

signal interact_pressed(target: Node)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _dragging_look:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	if event.is_action_pressed("interact"):
		interact_pressed.emit(get_cursor_collider())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_dragging_look = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_dragging_look = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("ui_cancel"):
		_dragging_look = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity = dir * MOVE_SPEED
	move_and_slide()


func _cursor_query() -> Dictionary:
	var mp: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mp)
	var to: Vector3 = from + camera.project_ray_normal(mp) * REACH
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
	var mp: Vector2 = get_viewport().get_mouse_position()
	return camera.project_ray_origin(mp) + camera.project_ray_normal(mp) * 1.2
