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
	var config_section:Variant = data.get("config", {})
	return float(config_section.get("zoom", default_value))

func get_tile_size(default_value: int = 32) -> int:
	var tileset := get_primary_tileset()
	return int(tileset.get("tile_size", default_value))

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

func get_metadata(default_value: Dictionary = {}) -> Dictionary:
	var metadata:Variant = data.get("metadata", default_value)
	if metadata is Dictionary:
		return metadata
	return default_value

func get_metadata_value(key: String, default_value: String = "") -> String:
	var metadata := get_metadata()
	return str(metadata.get(key, default_value))
