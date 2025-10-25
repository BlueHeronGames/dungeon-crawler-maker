extends RefCounted

## Produces dungeon layouts from configuration requests.
class_name DungeonLayoutGenerator

var _rng: RandomNumberGenerator
var _default_map_width: int
var _default_map_height: int
var _default_min_room_size: Vector2i
var _default_max_room_size: Vector2i
var _room_attempts: int
var _warnings: Array = []

func _init(rng: RandomNumberGenerator, defaults: Dictionary = {}) -> void:
	_rng = rng
	_default_map_width = defaults.get("map_width", 96)
	_default_map_height = defaults.get("map_height", 96)
	_default_min_room_size = defaults.get("min_room_size", Vector2i(4, 4))
	_default_max_room_size = defaults.get("max_room_size", Vector2i(10, 10))
	_room_attempts = defaults.get("room_attempts", 64)

func generate(room_requests: Array) -> Dictionary:
	_warnings.clear()
	var map_width := _default_map_width
	var map_height := _default_map_height

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

		var min_size := _read_size(request, "min_width", "min_height", "min_size", _default_min_room_size)
		var max_size := _read_size(request, "max_width", "max_height", "max_size", _default_max_room_size)

		min_size.x = max(3, min_size.x)
		min_size.y = max(3, min_size.y)
		max_size.x = max(min_size.x, max_size.x)
		max_size.y = max(min_size.y, max_size.y)

		var max_allowed_width:int = max(3, map_width - 2)
		var max_allowed_height:int = max(3, map_height - 2)
		if min_size.x > max_allowed_width or min_size.y > max_allowed_height:
			_warnings.append("DungeonMap: Room size exceeds map bounds; skipping request.")
			continue

		max_size.x = clamp(max_size.x, min_size.x, max_allowed_width)
		max_size.y = clamp(max_size.y, min_size.y, max_allowed_height)

		for _i in range(room_count):
			var room := _try_place_room(map_width, map_height, min_size, max_size, placed_rooms)
			if room == null or room.size == Vector2i.ZERO:
				continue

			placed_rooms.append(room)
			_carve_room(room, walkable)
			if placed_rooms.size() > 1:
				_connect_rooms(placed_rooms[placed_rooms.size() - 2], room, walkable)

			if placed_rooms.size() == 1:
				first_room_center = _rect_center(room)

	if placed_rooms.is_empty():
		var fallback := _build_fallback_room(map_width, map_height)
		_carve_room(fallback, walkable)
		first_room_center = _rect_center(fallback)

	return {
		"walkable": walkable,
		"player_spawn": first_room_center,
		"map_width": map_width,
		"map_height": map_height
	}

func _build_fallback_room(map_width: int, map_height: int) -> Rect2i:
	var width_hint:int = max(2, int(map_width / 6))
	var height_hint:int = max(2, int(map_height / 6))
	var half_size := Vector2i(
		max(2, min(_default_min_room_size.x, width_hint)),
		max(2, min(_default_min_room_size.y, height_hint))
	)
	var size := Vector2i(
		int(clamp(half_size.x * 2, 2, max(2, map_width - 2))),
		int(clamp(half_size.y * 2, 2, max(2, map_height - 2)))
	)
	var position := Vector2i(
		int(clamp(int(map_width / 2) - int(size.x / 2), 1, max(1, map_width - size.x - 1))),
		int(clamp(int(map_height / 2) - int(size.y / 2), 1, max(1, map_height - size.y - 1)))
	)
	return Rect2i(position, size)

func _read_size(data: Dictionary, width_key: String, height_key: String, array_key: String, default_value: Vector2i) -> Vector2i:
	var size_array:Array = data.get(array_key, null)
	if size_array is Array and size_array.size() >= 2:
		return Vector2i(int(size_array[0]), int(size_array[1]))

	return Vector2i(
		int(data.get(width_key, default_value.x)),
		int(data.get(height_key, default_value.y))
	)

func _try_place_room(map_width: int, map_height: int, min_size: Vector2i, max_size: Vector2i, existing_rooms: Array) -> Rect2i:
	for _attempt in range(_room_attempts):
		var width := _rng.randi_range(min_size.x, max_size.x)
		var height := _rng.randi_range(min_size.y, max_size.y)

		var x := _rng.randi_range(1, map_width - width - 1)
		var y := _rng.randi_range(1, map_height - height - 1)
		var candidate := Rect2i(x, y, width, height)

		if not _overlaps(candidate, existing_rooms):
			return candidate

	return Rect2i()

func _overlaps(candidate: Rect2i, existing_rooms: Array) -> bool:
	for existing in existing_rooms:
		if _expanded(existing, 1).intersects(candidate):
			return true
	return false

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

func get_warnings() -> Array:
	return _warnings.duplicate()
