extends Node

## Coordinates simultaneous grid-based turns for the player and nearby monsters.
class_name TurnManager

@export var dungeon_map_path: NodePath = NodePath("../Dungeon")
@export var player_path: NodePath = NodePath("../Player")
@export var monsters_container_path: NodePath = NodePath("../Monsters")
@export var monster_scene: PackedScene
@export var item_drop_scene: PackedScene
@export var console_path: NodePath = NodePath("../Console")

const MONSTER_COUNT := 5

@onready var _dungeon_map: DungeonMap = get_node_or_null(dungeon_map_path)
@onready var _player: Player = get_node_or_null(player_path)
@onready var _monsters_root: Node = get_node_or_null(monsters_container_path)
@onready var _console: MessageConsole = get_node_or_null(console_path)

var _monsters: Array = []
var _pending_player_direction: Vector2i = Vector2i.ZERO
var _tile_size: int = 32
var _config: GameConfig
var _monster_definitions: Array = []
var _monster_counter := 0
var _loot_system: LootSystem
var _items_on_floor: Dictionary = {} # cell -> {"name", "data", "node"}

func _ready() -> void:
	if _dungeon_map:
		_tile_size = _dungeon_map.get_tile_size()
	_config = GameConfig.load_from_file()
	_monster_definitions = _config.get_monster_definitions()
	_loot_system = LootSystem.new()
	_loot_system.set_config(_config)
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
			_configure_monster(monster)
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
		_configure_monster(instance)
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
	
	# Build current position map
	var current_cells := {}
	var reserved := {}
	for entity in entities:
		var cell := _dungeon_map.world_to_cell(entity.global_position)
		current_cells[entity] = cell
		reserved[cell] = true
	
	var player_cell: Vector2i = Vector2i.ZERO
	if current_cells.has(_player):
		player_cell = current_cells[_player]
	
	# Check if player is attacking a monster
	if _pending_player_direction != Vector2i.ZERO:
		var target_cell := player_cell + _pending_player_direction
		var target_monster := _get_monster_at_cell(target_cell, current_cells)
		if target_monster:
			_process_player_attack(target_monster, target_cell)
			_pending_player_direction = Vector2i.ZERO
			return
	
	# Normal movement turn
	var moves := []
	for entity in entities:
		var from_cell: Vector2i = current_cells[entity]
		reserved.erase(from_cell)
		var target_cell := _choose_target_cell(entity, from_cell, reserved, player_cell)
		reserved[target_cell] = true
		moves.append({
			"entity": entity,
			"from": from_cell,
			"to": target_cell
		})
	_pending_player_direction = Vector2i.ZERO
	
	# Execute moves
	var player_target_cell := player_cell
	var player_moved := false
	for move in moves:
		var to_cell: Vector2i = move["to"]
		var from_cell: Vector2i = move["from"]
		if to_cell == from_cell:
			if move["entity"] == _player:
				player_target_cell = to_cell
			continue
		var entity: Entity = move["entity"]
		var world_target := _dungeon_map.cell_to_world_center(to_cell)
		entity.move_to_position(world_target)
		if entity == _player:
			player_target_cell = to_cell
			player_moved = true

	_handle_player_cell_entry(player_target_cell, player_moved)

func _choose_target_cell(entity: Entity, from_cell: Vector2i, reserved: Dictionary, player_cell: Vector2i) -> Vector2i:
	var candidates := _get_move_candidates(entity, from_cell, player_cell)
	for direction:Vector2i in candidates:
		var candidate_cell := from_cell + direction
		if direction == Vector2i.ZERO:
			candidate_cell = from_cell
		if not _is_cell_available(candidate_cell, reserved):
			continue
		return candidate_cell
	return from_cell

func _get_move_candidates(entity: Entity, from_cell: Vector2i, player_cell: Vector2i) -> Array:
	if entity == _player:
		var moves := []
		if _pending_player_direction != Vector2i.ZERO:
			moves.append(_pending_player_direction)
		moves.append(Vector2i.ZERO)
		return moves
	if entity is Monster:
			return (entity as Monster).get_move_candidates(from_cell, player_cell, _dungeon_map)
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

func _configure_monster(monster: Monster) -> void:
	if monster == null:
		return
	monster.configure_for_tile_size(_tile_size)
	var definition := _get_monster_definition_for_index(_monster_counter)
	if not definition.is_empty():
		monster.configure_from_definition(definition)
	_monster_counter += 1

func _get_monster_definition_for_index(index: int) -> Dictionary:
	if _monster_definitions.is_empty():
		return {}
	var safe_index := index % _monster_definitions.size()
	return _monster_definitions[safe_index]

func _get_monster_at_cell(cell: Vector2i, current_cells: Dictionary) -> Monster:
	for entity in current_cells.keys():
		if entity is Monster and current_cells[entity] == cell:
			return entity as Monster
	return null

func _process_player_attack(target: Monster, target_cell: Vector2i) -> void:
	if _player == null or target == null:
		return
	
	# Deal damage
	target.take_damage(_player.attack)
	target.update_health_bar()
	
	# Play attack bump animation
	var player_pos := _player.global_position
	var target_pos := _dungeon_map.cell_to_world_center(target_cell)
	var halfway := player_pos.lerp(target_pos, 0.5)
	
	_player._is_moving = true
	var tween := create_tween()
	tween.tween_property(_player, "global_position", halfway, Entity.MOVE_DURATION * 0.5)
	tween.tween_property(_player, "global_position", player_pos, Entity.MOVE_DURATION * 0.5)
	tween.finished.connect(func(): _player._is_moving = false)
	
	# Remove dead monsters
	if not target.is_alive():
		_remove_monster(target)

func _remove_monster(monster: Monster) -> void:
	if monster in _monsters:
		_monsters.erase(monster)
	
	# Get monster's cell position before removing
	var monster_cell := _dungeon_map.world_to_cell(monster.global_position)
	
	# Roll for loot drop
	var loot_table := monster.get_loot_table()
	if loot_table and loot_table.size() > 0:
		var dropped_item := _loot_system.roll_loot(loot_table)
		if dropped_item != "" and not _items_on_floor.has(monster_cell):
			_spawn_item_drop(dropped_item, monster_cell)
	
	monster.queue_free()

func _spawn_item_drop(item_name: String, cell: Vector2i) -> void:
	if not item_drop_scene:
		push_error("item_drop_scene not assigned in TurnManager")
		return
	
	var item_drop := item_drop_scene.instantiate()
	add_child(item_drop)
	item_drop.global_position = _dungeon_map.cell_to_world_center(cell)
	
	var item_data := _loot_system.get_item_data(item_name)

	# Track item on floor with associated data and scene instance
	_items_on_floor[cell] = {
		"name": item_name,
		"data": item_data,
		"node": item_drop
	}

	item_drop.set_meta("item_name", item_name)
	item_drop.set_meta("item_data", item_data)

	var player_cell := _get_player_cell()
	if player_cell == cell:
		_notify_item_seen(item_name)

func _handle_player_cell_entry(cell: Vector2i, player_moved: bool) -> void:
	if not player_moved:
		return
	var entry : Variant = _items_on_floor.get(cell, null)
	if entry is Dictionary:
		var dictionary_entry := entry as Dictionary
		var item_name := str(dictionary_entry.get("name", ""))
		_notify_item_seen(item_name)
	elif _console:
		_console.clear_message()

func request_item_pickup() -> void:
	if _player == null or _dungeon_map == null:
		return

	var player_cell := _get_player_cell()
	if not _items_on_floor.has(player_cell):
		if _console:
			_console.show_message("Nothing to pick up.")
		return

	var entry : Dictionary = _items_on_floor[player_cell]
	if not (entry is Dictionary):
		_items_on_floor.erase(player_cell)
		if _console:
			_console.clear_message()
		return

	var item_entry := entry as Dictionary
	var item_name := str(item_entry.get("name", ""))
	var item_data : Dictionary = item_entry.get("data", {})
	var drop_node : Variant = item_entry.get("node")
	if drop_node is Node:
		var drop_node_cast := drop_node as Node
		if drop_node_cast.is_inside_tree():
			drop_node_cast.queue_free()

	_items_on_floor.erase(player_cell)

	if _player:
		_player.add_item_to_inventory(item_name, item_data)

	if _console:
		if item_name.is_empty():
			_console.clear_message()
		else:
			_console.show_item_picked_up(item_name)

func _notify_item_seen(item_name: String) -> void:
	if _console and not item_name.is_empty():
		_console.show_item_seen(item_name)

func show_console_message(message: String) -> void:
	if _console:
		_console.show_message(message)

func _get_player_cell() -> Vector2i:
	if _player == null or _dungeon_map == null:
		return Vector2i.ZERO
	return _dungeon_map.world_to_cell(_player.global_position)
