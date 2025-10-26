extends TileMap

## Generates dungeon rooms based on the configuration in game_data.json.
class_name DungeonMap

@export var player_path: NodePath

const DEFAULT_MAP_WIDTH := 96
const DEFAULT_MAP_HEIGHT := 96
const DEFAULT_MIN_ROOM_SIZE := Vector2i(4, 4)
const DEFAULT_MAX_ROOM_SIZE := Vector2i(10, 10)
const ROOM_PLACEMENT_ATTEMPTS := 64

var _config: GameConfig
var _rng := RandomNumberGenerator.new()
var _tile_size := 32
var _atlas_source_id := -1
var _tile_coords_by_type: Dictionary = {}
var _walkable_grid: Array = []
var _map_size: Vector2i = Vector2i(DEFAULT_MAP_WIDTH, DEFAULT_MAP_HEIGHT)
var _layout_generator: DungeonLayoutGenerator # delegates layout generation details

@onready var _player: Node2D = get_node_or_null(player_path)

func _ready() -> void:
	_config = GameConfig.load_from_file()
	_rng.randomize()
	_layout_generator = DungeonLayoutGenerator.new(_rng, {
		"map_width": DEFAULT_MAP_WIDTH,
		"map_height": DEFAULT_MAP_HEIGHT,
		"min_room_size": DEFAULT_MIN_ROOM_SIZE,
		"max_room_size": DEFAULT_MAX_ROOM_SIZE,
		"room_attempts": ROOM_PLACEMENT_ATTEMPTS
	})

	var tileset_info := _config.get_primary_tileset()
	_apply_tileset(tileset_info)

	var generation_result := _layout_generator.generate(_config.get_room_requests())
	for warning in _layout_generator.get_warnings():
		push_warning(warning)
	_walkable_grid = generation_result.get("walkable", [])
	_map_size = Vector2i(
		int(generation_result.get("map_width", DEFAULT_MAP_WIDTH)),
		int(generation_result.get("map_height", DEFAULT_MAP_HEIGHT))
	)
	_paint_tiles(generation_result)
	_position_player(generation_result)

func _apply_tileset(tileset_info: Dictionary) -> void:
	var build := DungeonTilesetBuilder.build(tileset_info, _tile_size)
	for warning in build.get("warnings", []):
		push_warning(str(warning))

	var new_tileset: TileSet = build.get("tile_set", null)
	if new_tileset == null:
		tile_set = null
		_atlas_source_id = -1
		_tile_coords_by_type.clear()
		return

	tile_set = new_tileset
	_tile_size = int(build.get("tile_size", _tile_size))
	_atlas_source_id = int(build.get("atlas_source_id", _atlas_source_id))
	_tile_coords_by_type = build.get("tile_coords_by_type", {})

func _paint_tiles(result: Dictionary) -> void:
	var walkable: Array = result.get("walkable", [])
	if walkable.is_empty():
		return
	if tile_set == null or _atlas_source_id == -1:
		push_warning("DungeonMap: Tile set missing; cannot paint map.")
		return

	var floor_coords = _tile_coords_by_type.get("floor", null)
	var wall_coords = _tile_coords_by_type.get("wall", null)
	var filler_coords = _tile_coords_by_type.get("filler", null)

	clear()
	var height := walkable.size()
	var width := 0
	if height > 0 and walkable[0] is Array:
		width = walkable[0].size()

	# First pass: paint floor tiles
	for y in range(height):
		var row = walkable[y]
		if not (row is Array):
			continue
		for x in range(width):
			if row[x] and floor_coords != null:
				set_cell(0, Vector2i(x, y), _atlas_source_id, floor_coords)

	# Second pass: paint walls (non-walkable cells adjacent to walkable cells)
	if wall_coords != null:
		for y in range(height):
			var row = walkable[y]
			if not (row is Array):
				continue
			for x in range(width):
				if row[x]:
					continue
				if _has_adjacent_walkable(walkable, x, y):
					set_cell(0, Vector2i(x, y), _atlas_source_id, wall_coords)

	# Third pass: fill remaining empty space with filler tiles
	if filler_coords != null:
		for y in range(height):
			var row = walkable[y]
			if not (row is Array):
				continue
			for x in range(width):
				if row[x]:
					continue
				if not _has_adjacent_walkable(walkable, x, y):
					set_cell(0, Vector2i(x, y), _atlas_source_id, filler_coords)



func _has_adjacent_walkable(grid: Array, x: int, y: int) -> bool:
	var offsets := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for offset in offsets:
		var nx:int = x + offset.x
		var ny:int = y + offset.y
		if ny < 0 or ny >= grid.size():
			continue
		var row = grid[ny]
		if not (row is Array):
			continue
		if nx < 0 or nx >= row.size():
			continue
		if row[nx]:
			return true
	return false

func _position_player(result: Dictionary) -> void:
	if _player == null:
		return

	var spawn: Vector2i = result.get("player_spawn", Vector2i.ZERO)
	_player.global_position = cell_to_world_center(spawn)

	if _player.has_method("configure_camera_limits"):
		_player.configure_camera_limits(_map_size, _tile_size)

func is_cell_walkable(cell: Vector2i) -> bool:
	if _walkable_grid.is_empty():
		return false
	if cell.x < 0 or cell.y < 0:
		return false
	if cell.y >= _walkable_grid.size():
		return false
	var row : Variant = _walkable_grid[cell.y]
	if not (row is Array):
		return false
	if cell.x >= row.size():
		return false
	return bool(row[cell.x])

func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	return Vector2i(
		int(floor(local_position.x / _tile_size)),
		int(floor(local_position.y / _tile_size))
	)

func cell_to_world_center(cell: Vector2i) -> Vector2:
	var local_position := Vector2(
		cell.x * _tile_size + _tile_size * 0.5,
		cell.y * _tile_size + _tile_size * 0.5
	)
	return to_global(local_position)

func get_tile_size() -> int:
	return _tile_size
