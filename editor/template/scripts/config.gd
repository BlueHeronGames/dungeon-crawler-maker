extends Node

## Stores and provides access to game_data.json settings.
class_name GameConfig

var data: Dictionary = {}

static func load_from_file(path: String = "res://game_data.json") -> GameConfig:
	var instance := GameConfig.new()
	instance._load(path)
	return instance

func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("GameConfig: Missing config file at %s" % path)
		data = {}
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameConfig: Unable to open %s" % path)
		data = {}
		return

	var json_result:Variant = JSON.parse_string(file.get_as_text())
	if typeof(json_result) == TYPE_DICTIONARY:
		data = json_result
	else:
		push_error("GameConfig: Invalid JSON structure in %s" % path)
		data = {}

func get_zoom(default_value: float = 1.0) -> float:
	var visuals := get_visuals()
	if visuals.has("zoom"):
		return float(visuals.get("zoom", default_value))
	var legacy_config: Variant = data.get("config", {})
	if legacy_config is Dictionary:
		return float((legacy_config as Dictionary).get("zoom", default_value))
	return default_value

func get_tile_size(default_value: int = 32) -> int:
	var tileset := get_primary_tileset()
	return int(tileset.get("tile_size", default_value))

func get_can_pass_turn(default_value: bool = false) -> bool:
	var gameplay := get_gameplay()
	if gameplay.has("can_pass_turn"):
		return bool(gameplay.get("can_pass_turn", default_value))
	var legacy_config: Variant = data.get("config", {})
	if legacy_config is Dictionary:
		return bool((legacy_config as Dictionary).get("can_pass_turn", default_value))
	return default_value

func get_primary_tileset() -> Dictionary:
	var tilesets:Variant = data.get("tilesets", [])
	if tilesets is Array and tilesets.size() > 0:
		return tilesets[0]
	return {}

func get_room_requests() -> Array:
	var rooms:Variant = data.get("rooms", [])
	if rooms is Array:
		return rooms
	return []

func get_project(default_value: Dictionary = {}) -> Dictionary:
	var project: Variant = data.get("project", default_value)
	if project is Dictionary:
		return project
	return default_value

func get_project_value(key: String, default_value: String = "") -> String:
	var project := get_project()
	return str(project.get(key, default_value))

func get_metadata(default_value: Dictionary = {}) -> Dictionary:
	return get_project(default_value)

func get_metadata_value(key: String, default_value: String = "") -> String:
	return get_project_value(key, default_value)

func get_visuals(default_value: Dictionary = {}) -> Dictionary:
	var visuals: Variant = data.get("visuals", null)
	if visuals is Dictionary:
		return visuals
	return default_value

func get_gameplay(default_value: Dictionary = {}) -> Dictionary:
	var gameplay: Variant = data.get("gameplay", null)
	if gameplay is Dictionary:
		return gameplay
	return default_value

func get_item_definitions() -> Dictionary:
	var items:Variant = data.get("items", {})
	if items is Dictionary:
		return items
	return {}

func get_monster_definitions() -> Array:
	var monsters:Variant = data.get("monsters", {})
	var result: Array = []
	if monsters is Dictionary:
		for id in monsters.keys():
			var entry = monsters[id]
			if entry is Dictionary:
				var definition := (entry as Dictionary).duplicate(true)
				definition["id"] = str(id)
				result.append(definition)
	return result
