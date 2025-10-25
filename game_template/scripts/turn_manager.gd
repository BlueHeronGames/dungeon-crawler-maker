extends Node

## Coordinates simultaneous grid-based turns for the player and nearby monsters.
class_name TurnManager

@export var dungeon_map_path: NodePath = NodePath("../Dungeon")
@export var player_path: NodePath = NodePath("../Player")
@export var monsters_container_path: NodePath = NodePath("../Monsters")
@export var monster_scene: PackedScene

const MONSTER_COUNT := 5

@onready var _dungeon_map: DungeonMap = get_node_or_null(dungeon_map_path)
@onready var _player: Player = get_node_or_null(player_path)
@onready var _monsters_root: Node = get_node_or_null(monsters_container_path)

var _monsters: Array = []
var _pending_player_direction: Vector2i = Vector2i.ZERO
var _tile_size: int = 32

func _ready() -> void:
	if _dungeon_map:
		_tile_size = _dungeon_map.get_tile_size()
	call_deferred("_initialize")

func process_player_input(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if not _can_process_turn():
		return
	_pending_player_direction = direction
	_execute_turn()

func _initialize() -> void:
	_collect_existing_monsters()
	if monster_scene and _monsters_root and _player and _dungeon_map:
		_spawn_test_monsters()

func _collect_existing_monsters() -> void:
	if _monsters_root == null:
		return
	_monsters.clear()
	for child in _monsters_root.get_children():
		if child is Monster:
			var monster := child as Monster
			monster.configure_for_tile_size(_tile_size)
			_monsters.append(monster)

func _spawn_test_monsters() -> void:
	var player_cell := _dungeon_map.world_to_cell(_player.global_position)
	var occupied := {}
	occupied[player_cell] = true
	for monster in _monsters:
		var cell := _dungeon_map.world_to_cell(monster.global_position)
		occupied[cell] = true
	var offsets := _generate_spawn_offsets(3)
	var spawned := 0
	for offset:Vector2i in offsets:
		if spawned >= MONSTER_COUNT:
			break
		var candidate_cell := player_cell + offset
		if not _dungeon_map.is_cell_walkable(candidate_cell):
			continue
		if occupied.has(candidate_cell):
			continue
		var instance: Monster = monster_scene.instantiate()
		_monsters_root.add_child(instance)
		instance.configure_for_tile_size(_tile_size)
		instance.global_position = _dungeon_map.cell_to_world_center(candidate_cell)
		_monsters.append(instance)
		occupied[candidate_cell] = true
		spawned += 1
	if spawned < MONSTER_COUNT:
		push_warning("TurnManager: Only %d monster(s) spawned; not enough nearby walkable tiles." % spawned)

func _generate_spawn_offsets(radius: int) -> Array:
	var offsets: Array = []
	for r in range(1, radius + 1):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				var cell := Vector2i(x, y)
				if cell == Vector2i.ZERO:
					continue
				if max(abs(cell.x), abs(cell.y)) != r:
					continue
				offsets.append(cell)
	offsets.shuffle()
	return offsets

func _execute_turn() -> void:
	if _player == null or _dungeon_map == null:
		_pending_player_direction = Vector2i.ZERO
		return
	var entities := _all_entities()
	if entities.is_empty():
		_pending_player_direction = Vector2i.ZERO
		return
	var current_cells := {}
	var reserved := {}
	for entity in entities:
		var cell := _dungeon_map.world_to_cell(entity.global_position)
		current_cells[entity] = cell
		reserved[cell] = true
	var moves := []
	for entity in entities:
		var from_cell: Vector2i = current_cells[entity]
		reserved.erase(from_cell)
		var target_cell := _choose_target_cell(entity, from_cell, reserved)
		reserved[target_cell] = true
		moves.append({
			"entity": entity,
			"from": from_cell,
			"to": target_cell
		})
	_pending_player_direction = Vector2i.ZERO
	for move in moves:
		var to_cell: Vector2i = move["to"]
		var from_cell: Vector2i = move["from"]
		if to_cell == from_cell:
			continue
		var entity: Entity = move["entity"]
		var world_target := _dungeon_map.cell_to_world_center(to_cell)
		entity.move_to_position(world_target)

func _choose_target_cell(entity: Entity, from_cell: Vector2i, reserved: Dictionary) -> Vector2i:
	var candidates := _get_move_candidates(entity)
	for direction:Vector2i in candidates:
		var candidate_cell := from_cell + direction
		if direction == Vector2i.ZERO:
			candidate_cell = from_cell
		if not _is_cell_available(candidate_cell, reserved):
			continue
		return candidate_cell
	return from_cell

func _get_move_candidates(entity: Entity) -> Array:
	if entity == _player:
		var moves := []
		if _pending_player_direction != Vector2i.ZERO:
			moves.append(_pending_player_direction)
		moves.append(Vector2i.ZERO)
		return moves
	if entity is Monster:
		return (entity as Monster).get_move_candidates()
	return [Vector2i.ZERO]

func _is_cell_available(cell: Vector2i, reserved: Dictionary) -> bool:
	if reserved.has(cell):
		return false
	return _dungeon_map.is_cell_walkable(cell)

func _all_entities() -> Array:
	var entities: Array = []
	if _player:
		entities.append(_player)
	for monster in _monsters:
		if monster:
			entities.append(monster)
	return entities

func _can_process_turn() -> bool:
	for entity in _all_entities():
		if not entity.can_accept_movement():
			return false
	return true
