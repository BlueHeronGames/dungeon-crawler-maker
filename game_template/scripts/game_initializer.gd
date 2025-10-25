extends Node

## Handles one-time game setup behaviors that rely on configuration data.
class_name GameInitializer

var _config: GameConfig

func _ready() -> void:
	_config = GameConfig.load_from_file()
	call_deferred("_apply_window_title")
	call_deferred("_setup_inventory_ui")

func _apply_window_title() -> void:
	var title := _config.get_metadata_value("title", "Dungeon Crawler")
	var version := _config.get_metadata_value("version", "").strip_edges()
	var window_title := title
	if not version.is_empty():
		window_title = "%s v%s" % [title, version]
	var window := get_window()
	if window:
		window.title = window_title
	# Not all platforms honor the window setter immediately, so we also ask the display server directly.
	DisplayServer.window_set_title(window_title)

func _setup_inventory_ui() -> void:
	var player := get_node_or_null("../Player") as Player
	var inventory_ui := get_node_or_null("../InventoryUI") as InventoryUI
	
	if player and inventory_ui:
		inventory_ui.set_player(player)
