extends Entity

## Player entity handles WASD input and applies camera settings from configuration.
class_name Player

@export var step_size: float = 32.0
@export var camera_path: NodePath = NodePath("Camera2D")

@onready var camera: Camera2D = get_node_or_null(camera_path)

var _config: GameConfig

func _ready() -> void:
	_config = GameConfig.load_from_file()
	_apply_camera_settings()

func _physics_process(_delta: float) -> void:
	if not can_accept_movement():
		return

	var direction := _read_movement_input()
	if direction == Vector2.ZERO:
		return

	move_by_offset(direction * step_size)

func _read_movement_input() -> Vector2:
	if Input.is_action_pressed("move_up"):
		return Vector2.UP
	if Input.is_action_pressed("move_down"):
		return Vector2.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2.RIGHT
	return Vector2.ZERO

func _apply_camera_settings() -> void:
	if camera == null:
		push_warning("Player: Camera node not found; cannot apply zoom or limits.")
		return

	camera.make_current()
	var zoom_value := _config.get_zoom(1.0)
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.limit_left = 0
	camera.limit_top = 0
