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

@onready var _player: Node2D = get_node_or_null(player_path)

func _ready() -> void:
	_config = GameConfig.load_from_file()
	_rng.randomize()

	var tileset_info := _config.get_primary_tileset()
	_configure_tileset(tileset_info)

	var generation_result := _generate_layout(_config.get_room_requests())
	_walkable_grid = generation_result.get("walkable", [])
	_map_size = Vector2i(
		int(generation_result.get("map_width", DEFAULT_MAP_WIDTH)),
		int(generation_result.get("map_height", DEFAULT_MAP_HEIGHT))
	)
	_paint_tiles(generation_result)
	_position_player(generation_result)

func _configure_tileset(tileset_info: Dictionary) -> void:
	if tileset_info.is_empty():
		push_warning("DungeonMap: No tileset information provided; generation will render empty.")
		return

	var tile_path := str(tileset_info.get("path", ""))
	if tile_path.is_empty():
		push_warning("DungeonMap: Tileset path missing in configuration.")
		return

	if not tile_path.begins_with("res://"):
		tile_path = "res://" + tile_path

	_tile_size = int(tileset_info.get("tile_size", _tile_size))

	var texture := load(tile_path)
	if texture == null:
		push_warning("DungeonMap: Failed to load tileset texture at %s" % tile_path)
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(_tile_size, _tile_size)

	var new_tileset := TileSet.new()
	new_tileset.tile_size = Vector2i(_tile_size, _tile_size)
	_atlas_source_id = new_tileset.add_source(atlas)
	tile_set = new_tileset
	_tile_coords_by_type.clear()

	var tile_definitions:Variant = tileset_info.get("tiles", [])
	if tile_definitions is Array and tile_definitions.size() > 0:
		_register_tile_definitions(tile_definitions, atlas, texture)
	else:
		atlas.create_tile(Vector2i.ZERO)
		_tile_coords_by_type["floor"] = Vector2i.ZERO

func _register_tile_definitions(tile_definitions: Array, atlas: TileSetAtlasSource, texture: Texture2D) -> void:
	var tex_size := texture.get_size()
	var columns:int = max(1, int(tex_size.x) / _tile_size)
	for tile_def in tile_definitions:
		if not (tile_def is Dictionary):
			continue

		var index := int(tile_def.get("id", -1))
		var type_name := str(tile_def.get("type", "")).to_lower()
		if index < 0 or type_name.is_empty():
			continue

		var coords := _atlas_coords_from_index(index, columns)
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)

		_tile_coords_by_type[type_name] = coords

	if not _tile_coords_by_type.has("floor"):
		var fallback := Vector2i.ZERO
		if not atlas.has_tile(fallback):
			atlas.create_tile(fallback)
		_tile_coords_by_type["floor"] = fallback

func _atlas_coords_from_index(index: int, columns: int) -> Vector2i:
	return Vector2i(index % columns, index / columns)

func _generate_layout(room_requests: Array) -> Dictionary:
	var map_width := DEFAULT_MAP_WIDTH
	var map_height := DEFAULT_MAP_HEIGHT

	for request in room_requests:
		if request is Dictionary:
			map_width = int(request.get("map_width", map_width))
			map_height = int(request.get("map_height", map_height))

	var walkable := []
	for _y in range(map_height):
		var row := []
		row.resize(map_width)
		for x in range(map_width):
			row[x] = false
		walkable.append(row)

	var placed_rooms: Array = []
	var first_room_center := Vector2i.ZERO

	for request in room_requests:
		if not (request is Dictionary):
			continue

		var room_type := str(request.get("type", "")).to_lower()
		if room_type != "rectangle" and room_type != "reactangle":
			continue

		var room_count := int(request.get("number", 0))
		if room_count <= 0:
			continue

		var min_size := _read_size(request, "min_width", "min_height", "min_size", DEFAULT_MIN_ROOM_SIZE)
		var max_size := _read_size(request, "max_width", "max_height", "max_size", DEFAULT_MAX_ROOM_SIZE)

		min_size.x = max(3, min_size.x)
		min_size.y = max(3, min_size.y)
		max_size.x = max(min_size.x, max_size.x)
		max_size.y = max(min_size.y, max_size.y)

		var max_allowed_width:int = max(3, map_width - 2)
		var max_allowed_height:int = max(3, map_height - 2)
		if min_size.x > max_allowed_width or min_size.y > max_allowed_height:
			push_warning("DungeonMap: Room size exceeds map bounds; skipping request.")
			continue

		max_size.x = clamp(max_size.x, min_size.x, max_allowed_width)
		max_size.y = clamp(max_size.y, min_size.y, max_allowed_height)

		for _i in range(room_count):
			var room := _try_place_room(map_width, map_height, min_size, max_size, placed_rooms)
			if room == null:
				continue

			placed_rooms.append(room)
			_carve_room(room, walkable)
			if placed_rooms.size() > 1:
				_connect_rooms(placed_rooms[placed_rooms.size() - 2], room, walkable)

			if placed_rooms.size() == 1:
				first_room_center = _rect_center(room)

	if placed_rooms.is_empty():
		var width_hint:int = max(2, int(map_width / 6))
		var height_hint:int = max(2, int(map_height / 6))
		var half_size := Vector2i(
			max(2, min(DEFAULT_MIN_ROOM_SIZE.x, width_hint)),
			max(2, min(DEFAULT_MIN_ROOM_SIZE.y, height_hint))
		)
		var size := Vector2i(
			int(clamp(half_size.x * 2, 2, max(2, map_width - 2))),
			int(clamp(half_size.y * 2, 2, max(2, map_height - 2)))
		)
		var position := Vector2i(
			int(clamp(int(map_width / 2) - int(size.x / 2), 1, max(1, map_width - size.x - 1))),
			int(clamp(int(map_height / 2) - int(size.y / 2), 1, max(1, map_height - size.y - 1)))
		)
		var fallback := Rect2i(position, size)
		_carve_room(fallback, walkable)
		first_room_center = _rect_center(fallback)

	return {
		"walkable": walkable,
		"player_spawn": first_room_center,
		"map_width": map_width,
		"map_height": map_height
	}

func _read_size(data: Dictionary, width_key: String, height_key: String, array_key: String, default_value: Vector2i) -> Vector2i:
	var size_array:Array = data.get(array_key, null)
	if size_array is Array and size_array.size() >= 2:
		return Vector2i(int(size_array[0]), int(size_array[1]))

	return Vector2i(
		int(data.get(width_key, default_value.x)),
		int(data.get(height_key, default_value.y))
	)

func _try_place_room(map_width: int, map_height: int, min_size: Vector2i, max_size: Vector2i, existing_rooms: Array) -> Rect2i:
	for _attempt in range(ROOM_PLACEMENT_ATTEMPTS):
		var width := _rng.randi_range(min_size.x, max_size.x)
		var height := _rng.randi_range(min_size.y, max_size.y)

		var x := _rng.randi_range(1, map_width - width - 1)
		var y := _rng.randi_range(1, map_height - height - 1)
		var candidate := Rect2i(x, y, width, height)

		var overlaps := false
		for existing in existing_rooms:
			if _expanded(existing, 1).intersects(candidate):
				overlaps = true
				break

		if not overlaps:
			return candidate

	return Rect2i()

func _expanded(rect: Rect2i, margin: int) -> Rect2i:
	var position := rect.position - Vector2i(margin, margin)
	var size := rect.size + Vector2i(margin * 2, margin * 2)
	return Rect2i(position, size)

func _carve_room(room: Rect2i, walkable: Array) -> void:
	for y in range(room.size.y):
		for x in range(room.size.x):
			var tile := room.position + Vector2i(x, y)
			walkable[tile.y][tile.x] = true

func _connect_rooms(a: Rect2i, b: Rect2i, walkable: Array) -> void:
	var center_a := _rect_center(a)
	var center_b := _rect_center(b)

	if _rng.randi_range(0, 1) == 0:
		_carve_horizontal_tunnel(center_a.x, center_b.x, center_a.y, walkable)
		_carve_vertical_tunnel(center_a.y, center_b.y, center_b.x, walkable)
	else:
		_carve_vertical_tunnel(center_a.y, center_b.y, center_a.x, walkable)
		_carve_horizontal_tunnel(center_a.x, center_b.x, center_b.y, walkable)

func _carve_horizontal_tunnel(x1: int, x2: int, y: int, walkable: Array) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		if y >= 0 and y < walkable.size() and x >= 0 and x < walkable[y].size():
			walkable[y][x] = true

func _carve_vertical_tunnel(y1: int, y2: int, x: int, walkable: Array) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		if y >= 0 and y < walkable.size() and x >= 0 and x < walkable[y].size():
			walkable[y][x] = true

func _rect_center(rect: Rect2i) -> Vector2i:
	return Vector2i(
		rect.position.x + int(rect.size.x / 2),
		rect.position.y + int(rect.size.y / 2)
	)

func _paint_tiles(result: Dictionary) -> void:
	var walkable: Array = result.get("walkable", [])
	if walkable.is_empty():
		return
	if tile_set == null or _atlas_source_id == -1:
		push_warning("DungeonMap: Tile set missing; cannot paint map.")
		return

	var floor_coords = _tile_coords_by_type.get("floor", null)
	var wall_coords = _tile_coords_by_type.get("wall", null)

	clear()
	var height := walkable.size()
	var width := 0
	if height > 0 and walkable[0] is Array:
		width = walkable[0].size()

	for y in range(height):
		var row = walkable[y]
		if not (row is Array):
			continue
		for x in range(width):
			if row[x] and floor_coords != null:
				set_cell(0, Vector2i(x, y), _atlas_source_id, floor_coords)

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
