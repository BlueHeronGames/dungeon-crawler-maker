extends Entity

## Simple monster that requests random cardinal moves each turn.
class_name Monster

@export var step_size: float = 32.0
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var sprite_path: NodePath = NodePath("Sprite2D")

@onready var _collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path)
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func configure_for_tile_size(tile_size: int) -> void:
	step_size = float(tile_size)
	if _collision_shape:
		_collision_shape.position = Vector2.ZERO
		if _collision_shape.shape is RectangleShape2D:
			var rect := _collision_shape.shape as RectangleShape2D
			var padding:float = max(1.0, tile_size * 0.05)
			rect.size = Vector2(tile_size - padding, tile_size - padding)
	if _sprite:
		var base_size := Vector2.ONE
		if _sprite.region_enabled:
			base_size = _sprite.region_rect.size
		elif _sprite.texture:
			base_size = _sprite.texture.get_size()
		if base_size.x != 0 and base_size.y != 0:
			var scale := tile_size / base_size.x
			_sprite.scale = Vector2(scale, scale)

func get_move_candidates() -> Array:
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	_shuffle(directions)
	directions.append(Vector2i.ZERO)
	return directions

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[swap_index]
		items[swap_index] = temp
