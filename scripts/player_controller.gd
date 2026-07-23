extends CharacterBody3D
## First-person player controller: mouse look, pointer lock, WASD, interaction.

const MOUSE_SENSITIVITY: float = 0.0025
const MOVE_SPEED: float = 3.0
const PITCH_LIMIT: float = deg_to_rad(80.0)

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractionRay

# Interaction target the ray is currently hitting (instrument / slot / surgeon hand)
var hover_target: Node = null
# Emitted when interact is pressed; passes the current hover target
signal interact_pressed(target: Node)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("interact"):
		interact_pressed.emit(ray.get_collider())


func _physics_process(_delta: float) -> void:
	# Update hover target from ray
	var collider: Object = ray.get_collider()
	hover_target = collider as Node

	# Movement (optional; player mostly stands at the table)
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity = dir * MOVE_SPEED
	move_and_slide()
