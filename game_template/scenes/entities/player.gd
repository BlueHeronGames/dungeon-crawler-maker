extends Entity

## Player entity handles WASD input and applies camera settings from configuration.
class_name Player

@export var step_size: float = 32.0
@export var camera_path: NodePath = NodePath("Camera2D")
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var sprite_path: NodePath = NodePath("Sprite2D")

@onready var camera: Camera2D = get_node_or_null(camera_path)
@onready var _collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path)
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)

var _config: GameConfig

func _ready() -> void:
	_config = GameConfig.load_from_file()
	_apply_tile_metrics(_config.get_tile_size(int(step_size)))
	_apply_camera_settings()

func _physics_process(_delta: float) -> void:
	if not can_accept_movement():
		return

	var direction := _read_movement_input()
	if direction == Vector2.ZERO:
		return

	move_by_offset(direction * step_size)

func _read_movement_input() -> Vector2:
	var horizontal := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var vertical := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var direction := Vector2(horizontal, vertical)

	if direction == Vector2.ZERO:
		return Vector2.ZERO

	# Prevent diagonal movement to preserve grid-based stepping.
	if abs(direction.x) > 0 and abs(direction.y) > 0:
		if abs(direction.x) >= abs(direction.y):
			direction.y = 0
		else:
			direction.x = 0

	return direction.normalized()

func _apply_camera_settings() -> void:
	if camera == null:
		push_warning("Player: Camera node not found; cannot apply zoom or limits.")
		return

	camera.make_current()
	var zoom_value := _config.get_zoom(1.0)
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.limit_left = 0
	camera.limit_top = 0

func configure_camera_limits(map_size: Vector2i, tile_size: int) -> void:
	if camera == null:
		return

	var width_pixels:int = max(0, map_size.x * tile_size)
	var height_pixels:int = max(0, map_size.y * tile_size)
	camera.limit_right = max(0, width_pixels - tile_size)
	camera.limit_bottom = max(0, height_pixels - tile_size)

func _apply_tile_metrics(tile_size: int) -> void:
	step_size = float(tile_size)
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		var rect := _collision_shape.shape as RectangleShape2D
		rect.size = Vector2(tile_size, tile_size)
		_collision_shape.position = Vector2(tile_size * 0.5, tile_size * 0.5)
	if _sprite:
		var base_size := Vector2.ONE
		if _sprite.region_enabled:
			base_size = _sprite.region_rect.size
		elif _sprite.texture:
			base_size = _sprite.texture.get_size()
		if base_size.x != 0 and base_size.y != 0:
			var scale := tile_size / base_size.x
			_sprite.scale = Vector2(scale, scale)
