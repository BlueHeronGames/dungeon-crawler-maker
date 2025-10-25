extends Entity

## Simple monster that delegates movement decisions to an AI behavior.
class_name Monster

@export var step_size: float = 32.0
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var sprite_path: NodePath = NodePath("Sprite2D")

@onready var _collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path)
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)

var _rng := RandomNumberGenerator.new()
var _ai_type := "random"
var _behavior: MonsterBehavior = null

func _ready() -> void:
	_rng.randomize()
	_apply_ai_behavior()

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

func get_move_candidates(current_cell: Vector2i, player_cell: Vector2i, dungeon_map: DungeonMap) -> Array:
	if _behavior == null:
		_apply_ai_behavior()
	return _behavior.get_move_candidates(self, current_cell, player_cell, dungeon_map)

func shuffle_directions(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[swap_index]
		items[swap_index] = temp

func configure_from_definition(definition: Dictionary) -> void:
	if definition.has("ai_type"):
		set_ai_type(str(definition.get("ai_type", "random")))

func set_ai_type(ai_type: String) -> void:
	_ai_type = ai_type.to_lower()
	_apply_ai_behavior()

func get_ai_type() -> String:
	return _ai_type

func _apply_ai_behavior() -> void:
	match _ai_type:
		"passive":
			_behavior = PassiveChaseBehavior.new()
		_:
			_behavior = RandomRoamBehavior.new()

class MonsterBehavior:
	func get_move_candidates(monster: Monster, current_cell: Vector2i, player_cell: Vector2i, dungeon_map: DungeonMap) -> Array:
		return [Vector2i.ZERO]

class RandomRoamBehavior extends MonsterBehavior:
	func get_move_candidates(monster: Monster, current_cell: Vector2i, player_cell: Vector2i, dungeon_map: DungeonMap) -> Array:
		var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		monster.shuffle_directions(directions)
		directions.append(Vector2i.ZERO)
		return directions

class PassiveChaseBehavior extends MonsterBehavior:
	const TRIGGER_RANGE := 3

	func get_move_candidates(monster: Monster, current_cell: Vector2i, player_cell: Vector2i, dungeon_map: DungeonMap) -> Array:
		var delta := player_cell - current_cell
		var distance : int = abs(delta.x) + abs(delta.y)
		if distance == 0:
			return [Vector2i.ZERO]
		if distance > TRIGGER_RANGE:
			return [Vector2i.ZERO]

		var candidates: Array = []
		var ordered := _ordered_axes(delta)
		for dir in ordered:
			if dir != Vector2i.ZERO and not dir in candidates:
				candidates.append(dir)
		for i in range(ordered.size() - 1, -1, -1):
			var dir_rev: Vector2i = ordered[i]
			if dir_rev != Vector2i.ZERO and not dir_rev in candidates:
				candidates.append(dir_rev)
		candidates.append(Vector2i.ZERO)
		return candidates

	func _ordered_axes(delta: Vector2i) -> Array:
		var step_x := _step(delta.x)
		var step_y := _step(delta.y)
		var ordered: Array = []
		if abs(delta.x) >= abs(delta.y):
			ordered.append(Vector2i(step_x, 0))
			ordered.append(Vector2i(0, step_y))
		else:
			ordered.append(Vector2i(0, step_y))
			ordered.append(Vector2i(step_x, 0))
		return ordered

	func _step(delta: int) -> int:
		if delta > 0:
			return 1
		if delta < 0:
			return -1
		return 0
