extends Node

## Stores and provides access to dungeon_crawler.json settings.
class_name GameConfig

var data: Dictionary = {}

static func load_from_file(path: String = "res://dungeon_crawler.json") -> GameConfig:
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
