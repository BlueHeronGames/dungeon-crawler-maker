extends Control

@onready var export_button: Button = %ExportButton
@onready var run_button: Button = %RunButton
@onready var project_path_label: Label = %ProjectPathLabel
@onready var status_dialog: AcceptDialog = %StatusDialog
@onready var error_dialog: AcceptDialog = %ErrorDialog
@onready var file_menu_button: MenuButton = %FileMenu
@onready var properties_dialog: AcceptDialog = %PropertiesDialog
@onready var properties_sidebar: VBoxContainer = %PropertiesSidebar
@onready var project_button: Button = %ProjectButton
@onready var visuals_button: Button = %VisualsButton
@onready var gameplay_button: Button = %GameplayButton
@onready var tilesets_button: Button = %TilesetsButton
@onready var properties_tabs: TabContainer = %PropertiesTabs
@onready var project_panel: Control = %ProjectPanel
@onready var project_title_field: LineEdit = %ProjectTitleField
@onready var project_author_field: LineEdit = %ProjectAuthorField
@onready var project_version_field: LineEdit = %ProjectVersionField
@onready var project_description_field: TextEdit = %ProjectDescriptionField
@onready var visuals_panel: Control = %VisualsPanel
@onready var visuals_zoom_field: SpinBox = %VisualsZoomField
@onready var gameplay_panel: Control = %GameplayPanel
@onready var gameplay_can_pass_turn_field: CheckBox = %GameplayCanPassTurnField
@onready var tilesets_panel: Control = %TilesetsPanel
@onready var tileset_add_button: Button = %TilesetAddButton
@onready var tileset_remove_button: Button = %TilesetRemoveButton
@onready var tileset_list_container: VBoxContainer = %TilesetList
@onready var tileset_id_field: LineEdit = %TilesetIdField
@onready var tileset_path_field: LineEdit = %TilesetPathField
@onready var tileset_browse_button: Button = %TilesetBrowseButton
@onready var tileset_tile_size_field: SpinBox = %TilesetTileSizeField
@onready var tileset_tiles_list: ItemList = %TilesetTilesList
@onready var tileset_tiles_hint: Label = %TilesetTilesHint
@onready var tileset_form: VBoxContainer = %TilesetForm
@onready var tileset_empty_label: Label = %TilesetEmptyLabel
@onready var tileset_path_dialog: FileDialog = %TilesetPathDialog

var project_data_path := ""
var _return_to_picker_on_error := false
var _game_data: Dictionary = {}
var _is_dirty := false
var _syncing_properties := false
var _current_tileset_index := -1
var _tileset_buttons: Array[Button] = []
var _tileset_button_group := ButtonGroup.new()
var _suppress_tileset_button_signal := false

const FILE_MENU_PROPERTIES_ID := 0
const PROJECT_FIELDS := ["title", "author", "version", "description"]
const TILESET_DEFAULT_TILE_SIZE := 32

func _ready() -> void:
	export_button.pressed.connect(_on_export_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	error_dialog.confirmed.connect(_on_error_dialog_confirmed)
	var file_popup: PopupMenu = file_menu_button.get_popup()
	file_popup.clear()
	file_popup.add_item("Properties", FILE_MENU_PROPERTIES_ID)
	file_popup.id_pressed.connect(_on_file_menu_id_pressed)
	properties_dialog.confirmed.connect(_on_properties_dialog_confirmed)
	properties_dialog.canceled.connect(_on_properties_dialog_canceled)
	project_title_field.text_changed.connect(_on_project_field_changed)
	project_author_field.text_changed.connect(_on_project_field_changed)
	project_version_field.text_changed.connect(_on_project_field_changed)
	project_description_field.text_changed.connect(_on_project_description_changed)
	visuals_zoom_field.value_changed.connect(_on_visuals_zoom_changed)
	gameplay_can_pass_turn_field.toggled.connect(_on_gameplay_can_pass_turn_toggled)
	properties_dialog.ok_button_text = "Save"
	tileset_add_button.pressed.connect(_on_tileset_add_button_pressed)
	tileset_remove_button.pressed.connect(_on_tileset_remove_button_pressed)
	tileset_id_field.text_changed.connect(_on_tileset_id_changed)
	tileset_path_field.text_changed.connect(_on_tileset_path_changed)
	tileset_browse_button.pressed.connect(_on_tileset_browse_button_pressed)
	tileset_tile_size_field.value_changed.connect(_on_tileset_tile_size_changed)
	if tileset_path_dialog:
		tileset_path_dialog.file_selected.connect(_on_tileset_file_selected)
	_initialize_properties_sidebar()
	_initialize_project_context()

func _initialize_project_context() -> void:
	if !get_tree().has_meta("project_data_path"):
		_show_error("No project selected.", true)
		return
	project_data_path = str(get_tree().get_meta("project_data_path"))
	if project_data_path.is_empty():
		_show_error("No project selected.", true)
		return
	project_path_label.text = "Project Path: %s" % project_data_path
	if !FileAccess.file_exists(project_data_path):
		_show_error("game_data.json not found at:\n%s" % project_data_path, true)
		return
	var file := FileAccess.open(project_data_path, FileAccess.READ)
	if file == null:
		_show_error("Unable to open game_data.json for reading.", true)
		return
	var raw_text := file.get_as_text()
	file.close()
	if !_load_game_data(raw_text):
		return
	_refresh_properties_ui()
	_focus_properties_tab(project_panel)

func _on_export_button_pressed() -> void:
	if !_save_game_data():
		return
	
	# Show status dialog
	status_dialog.dialog_text = "Exporting game..."
	status_dialog.call_deferred("popup_centered")
	await get_tree().process_frame
	await get_tree().process_frame
	
	var prep_result := _prepare_runtime_directory()
	if !prep_result.get("ok", false):
		status_dialog.hide()
		_show_error(str(prep_result.get("error", "Failed to prepare runtime directory.")))
		return
	var runtime_path := str(prep_result.get("path", ""))
	if runtime_path.is_empty():
		status_dialog.hide()
		_show_error("Failed to determine runtime directory.")
		return
	
	# Export the game
	if !_export_game(runtime_path):
		status_dialog.hide()
		_show_error("Unable to export game. Ensure bin/godot.exe exists.")
		return
	
	status_dialog.hide()
	_show_status("Export complete!")

func _on_run_button_pressed() -> void:
	if !_save_game_data():
		return
	
	# Show status dialog immediately before any heavy work
	status_dialog.dialog_text = "Importing and launching game runtime..."
	status_dialog.call_deferred("popup_centered")
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure dialog is visible
	
	var prep_result := _prepare_runtime_directory()
	if !prep_result.get("ok", false):
		status_dialog.hide()
		_show_error(str(prep_result.get("error", "Failed to prepare runtime directory.")))
		return
	var runtime_path := str(prep_result.get("path", ""))
	if runtime_path.is_empty():
		status_dialog.hide()
		_show_error("Failed to determine runtime directory.")
		return
	if !_launch_runtime(runtime_path):
		status_dialog.hide()
		_show_error("Unable to locate the Godot executable in bin/godot.exe.")
		return
	# Close the status dialog after launching
	status_dialog.hide()

func _save_game_data() -> bool:
	if _game_data.is_empty():
		_show_error("No game data is loaded.")
		return false
	_update_project_from_ui()
	_update_visuals_from_ui()
	_update_gameplay_from_ui()
	var file := FileAccess.open(project_data_path, FileAccess.WRITE)
	if file == null:
		_show_error("Unable to save game_data.json for export.")
		return false
	var json_text := JSON.stringify(_game_data, "\t")
	if !json_text.ends_with("\n"):
		json_text += "\n"
	file.store_string(json_text)
	file.close()
	_is_dirty = false
	return true

func _show_status(message: String) -> void:
	status_dialog.dialog_text = message
	status_dialog.call_deferred("popup_centered")

func _show_error(message: String, return_to_picker: bool = false) -> void:
	_return_to_picker_on_error = return_to_picker
	error_dialog.dialog_text = message
	error_dialog.call_deferred("popup_centered")

func _on_error_dialog_confirmed() -> void:
	if _return_to_picker_on_error:
		_return_to_picker_on_error = false
		_get_back_to_project_picker()

func _get_back_to_project_picker() -> void:
	var tree := get_tree()
	tree.set_meta("project_data_path", "")
	tree.change_scene_to_file("res://scenes/select_project_scene.tscn")

# Copies the embedded runtime template, project data, and optional assets into a fresh .game folder.
func _prepare_runtime_directory() -> Dictionary:
	if project_data_path.is_empty():
		return {"ok": false, "error": "No project selected."}
	var project_dir := project_data_path.get_base_dir()
	if project_dir.is_empty():
		return {"ok": false, "error": "Unable to determine project directory."}
	var runtime_dir := project_dir.path_join(".game")
	var dir_err := DirAccess.make_dir_recursive_absolute(runtime_dir)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "Unable to create runtime folder (%d)." % dir_err}
	var clear_err := _clear_directory(runtime_dir)
	if clear_err != OK:
		return {"ok": false, "error": "Unable to clear runtime folder (%d)." % clear_err}
	var template_path := "res://template"
	var copy_template_err := _copy_directory(template_path, runtime_dir)
	if copy_template_err != OK:
		return {"ok": false, "error": "Failed to copy runtime template (%d)." % copy_template_err}
	var copy_data_err := _copy_file(project_data_path, runtime_dir.path_join("game_data.json"))
	if copy_data_err != OK:
		return {"ok": false, "error": "Failed to copy game_data.json (%d)." % copy_data_err}
	var assets_source := project_dir.path_join("assets")
	if DirAccess.dir_exists_absolute(assets_source):
		var assets_err := _copy_directory(assets_source, runtime_dir.path_join("assets"))
		if assets_err != OK:
			return {"ok": false, "error": "Failed to copy project assets (%d)." % assets_err}
	
	# Import the project so Godot can run it
	var import_result := _import_project(runtime_dir)
	if !import_result:
		return {"ok": false, "error": "Failed to import the runtime project."}
	
	return {"ok": true, "path": runtime_dir}

func _clear_directory(path: String) -> int:
	if !DirAccess.dir_exists_absolute(path):
		return OK
	var dir := DirAccess.open(path)
	if dir == null:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var entry_path := path.path_join(entry)
		if dir.current_is_dir():
			var inner_err := _clear_directory(entry_path)
			if inner_err != OK:
				dir.list_dir_end()
				return inner_err
			var remove_dir_err := DirAccess.remove_absolute(entry_path)
			if remove_dir_err != OK:
				dir.list_dir_end()
				return remove_dir_err
		else:
			var remove_err := DirAccess.remove_absolute(entry_path)
			if remove_err != OK:
				dir.list_dir_end()
				return remove_err
	dir.list_dir_end()
	return OK

func _copy_directory(source: String, destination: String) -> int:
	var src_dir := DirAccess.open(source)
	if src_dir == null:
		return ERR_CANT_OPEN
	var make_err := DirAccess.make_dir_recursive_absolute(destination)
	if make_err != OK and make_err != ERR_ALREADY_EXISTS:
		return make_err
	src_dir.list_dir_begin()
	while true:
		var entry := src_dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var from_path := source.path_join(entry)
		var to_path := destination.path_join(entry)
		if src_dir.current_is_dir():
			var dir_err := _copy_directory(from_path, to_path)
			if dir_err != OK:
				src_dir.list_dir_end()
				return dir_err
		else:
			var file_err := _copy_file(from_path, to_path)
			if file_err != OK:
				src_dir.list_dir_end()
				return file_err
	src_dir.list_dir_end()
	return OK

func _copy_file(source: String, destination: String) -> int:
	var src_file := FileAccess.open(source, FileAccess.READ)
	if src_file == null:
		return ERR_CANT_OPEN
	var ensure_dir_err := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if ensure_dir_err != OK and ensure_dir_err != ERR_ALREADY_EXISTS:
		src_file.close()
		return ensure_dir_err
	var dest_file := FileAccess.open(destination, FileAccess.WRITE)
	if dest_file == null:
		src_file.close()
		return ERR_CANT_OPEN
	dest_file.store_buffer(src_file.get_buffer(src_file.get_length()))
	dest_file.close()
	src_file.close()
	return OK

func _import_project(runtime_path: String) -> bool:
	# Skip import if .godot folder already exists and is recent
	var godot_dir := runtime_path.path_join(".godot")
	var project_godot := runtime_path.path_join("project.godot")
	
	if DirAccess.dir_exists_absolute(godot_dir) and FileAccess.file_exists(project_godot):
		var godot_time := FileAccess.get_modified_time(godot_dir.path_join("uid_cache.bin"))
		var project_time := FileAccess.get_modified_time(project_godot)
		# If .godot folder is newer than project.godot, skip import
		if godot_time > 0 and godot_time >= project_time:
			return true
	
	# Run Godot with --headless --import --quit to import the project without opening a window
	var args := PackedStringArray(["--path", runtime_path, "--headless", "--import", "--quit"])
	for executable in _get_godot_executable_candidates():
		var output: Array = []
		var exit_code := OS.execute(executable, args, output, true, false)
		if exit_code == 0 or exit_code == -2:  # -2 means process still running, which is ok
			return true
	return false

func _launch_runtime(runtime_path: String) -> bool:
	# Use --path to specify project, then add -- to signal we want to run it
	var args := PackedStringArray(["--path", runtime_path, "--"])
	for executable in _get_godot_executable_candidates():
		var pid := OS.create_process(executable, args)
		if pid > 0:
			return true
	return false

func _export_game(runtime_path: String) -> bool:
	# First import the project
	if !_import_project(runtime_path):
		push_error("Failed to import project before export")
		return false
	
	# Get export path
	var project_dir := project_data_path.get_base_dir()
	var export_path := project_dir.path_join("export")
	DirAccess.make_dir_recursive_absolute(export_path)
	
	# Determine export file name based on project
	var project_name := project_dir.get_file()
	if project_name.is_empty():
		project_name = "game"
	var export_file := export_path.path_join(project_name + ".exe")
	
	# Export using Godot CLI with the first preset
	var args := PackedStringArray([
		"--path", runtime_path,
		"--headless",
		"--export-release", "Windows Desktop",
		export_file
	])
	
	var candidates := _get_godot_executable_candidates()
	if candidates.is_empty():
		push_error("No Godot executable found")
		return false
	
	for executable in candidates:
		print("Attempting export with: ", executable)
		print("Args: ", args)
		var output: Array = []
		var exit_code := OS.execute(executable, args, output, true, false)
		print("Export exit code: ", exit_code)
		for line in output:
			print("  ", line)
		if exit_code == 0:
			return true
	return false

# Provides a prioritized list of Godot executables to try when launching the runtime.
func _get_godot_executable_candidates() -> Array[String]:
	var candidates: Array[String] = []
	# ONLY use the bundled Windows executable to avoid PATH incompatibilities
	var bundled_paths := [
		ProjectSettings.globalize_path("res://../bin/godot.exe"),
		ProjectSettings.globalize_path("res://../bin/godot")
	]
	for path in bundled_paths:
		if path != "" and FileAccess.file_exists(path):
			candidates.append(path)
	return candidates

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		FILE_MENU_PROPERTIES_ID:
			_open_properties_dialog()


func _open_properties_dialog() -> void:
	_refresh_properties_ui()
	_focus_properties_tab(project_panel)
	properties_dialog.call_deferred("popup_centered")

func _focus_properties_tab(panel: Control) -> void:
	if properties_tabs == null or panel == null:
		return
	var tab_index := properties_tabs.get_tab_idx_from_control(panel)
	if tab_index >= 0:
		_sync_properties_tab_selection(tab_index)

func _initialize_properties_sidebar() -> void:
	if properties_tabs == null or properties_sidebar == null:
		return
	properties_tabs.tabs_visible = false
	var buttons : Array[Button] = [project_button, visuals_button, gameplay_button, tilesets_button]
	for index in range(buttons.size()):
		var button := buttons[index]
		if button == null:
			continue
		button.pressed.connect(_on_properties_button_pressed.bind(index))
		button.button_pressed = (index == properties_tabs.current_tab)
	_sync_properties_tab_selection(properties_tabs.current_tab)

func _on_properties_button_pressed(tab: int) -> void:
	_sync_properties_tab_selection(tab)

func _sync_properties_tab_selection(tab: int) -> void:
	if properties_tabs == null:
		return
	var clamped_tab := clampi(tab, 0, properties_tabs.get_tab_count() - 1)
	properties_tabs.current_tab = clamped_tab
	var matrix := {
		0: project_button,
		1: visuals_button,
		2: gameplay_button,
		3: tilesets_button
	}
	for key in matrix.keys():
		var button: Button = matrix[key]
		if button != null:
			button.button_pressed = (key == clamped_tab)

func _refresh_properties_ui() -> void:
	var project := _ensure_project_dictionary()
	var visuals := _ensure_visuals_dictionary()
	var gameplay := _ensure_gameplay_dictionary()
	_syncing_properties = true
	project_title_field.text = str(project.get("title", ""))
	project_author_field.text = str(project.get("author", ""))
	project_version_field.text = str(project.get("version", ""))
	project_description_field.text = str(project.get("description", ""))
	visuals_zoom_field.value = float(visuals.get("zoom", 1.0))
	gameplay_can_pass_turn_field.button_pressed = bool(gameplay.get("can_pass_turn", false))
	_refresh_tilesets_ui()
	_syncing_properties = false
	_is_dirty = false
	
func _on_properties_dialog_confirmed() -> void:
	if !_save_game_data():
		_refresh_properties_ui()
		properties_dialog.call_deferred("popup_centered")

func _on_properties_dialog_canceled() -> void:
	_refresh_properties_ui()

func _on_project_field_changed(_new_text: String) -> void:
	if _syncing_properties:
		return
	_mark_dirty()

func _on_project_description_changed() -> void:
	if _syncing_properties:
		return
	_mark_dirty()

func _mark_dirty() -> void:
	_is_dirty = true

func _load_game_data(raw_text: String) -> bool:
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		_show_error("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()], true)
		return false
	var parsed : Variant = json.get_data()
	if parsed is Dictionary:
		_game_data = parsed
		_migrate_game_data()
		return true
	_show_error("game_data.json must contain a JSON object at the root.", true)
	return false

func _migrate_game_data() -> void:
	var had_metadata := _game_data.has("metadata")
	if had_metadata and !_game_data.has("project"):
		var legacy : Variant = _game_data.get("metadata")
		if legacy is Dictionary:
			_game_data["project"] = (legacy as Dictionary).duplicate(true)
		else:
			_game_data["project"] = {}
	if had_metadata:
		_game_data.erase("metadata")
	if _game_data.has("config"):
		var config : Variant = _game_data.get("config")
		if config is Dictionary:
			var visuals := _ensure_visuals_dictionary()
			if config.has("zoom"):
				visuals["zoom"] = config.get("zoom")
			var gameplay := _ensure_gameplay_dictionary()
			if config.has("can_pass_turn"):
				gameplay["can_pass_turn"] = config.get("can_pass_turn")
		_game_data.erase("config")
	_ensure_project_dictionary()
	_ensure_visuals_dictionary()
	_ensure_gameplay_dictionary()

func _ensure_project_dictionary() -> Dictionary:
	var project : Variant = _game_data.get("project")
	if !(project is Dictionary):
		project = {}
		_game_data["project"] = project
	for field in PROJECT_FIELDS:
		if !project.has(field):
			project[field] = ""
	return project

func _ensure_visuals_dictionary() -> Dictionary:
	var visuals : Variant = _game_data.get("visuals")
	if !(visuals is Dictionary):
		visuals = {}
		_game_data["visuals"] = visuals
	if !visuals.has("zoom"):
		visuals["zoom"] = 1.0
	return visuals

func _ensure_gameplay_dictionary() -> Dictionary:
	var gameplay : Variant = _game_data.get("gameplay")
	if !(gameplay is Dictionary):
		gameplay = {}
		_game_data["gameplay"] = gameplay
	if !gameplay.has("can_pass_turn"):
		gameplay["can_pass_turn"] = false
	return gameplay

func _ensure_tilesets_array() -> Array:
	var tilesets_variant : Variant = _game_data.get("tilesets")
	if !(tilesets_variant is Array):
		var new_tilesets: Array = []
		_game_data["tilesets"] = new_tilesets
		tilesets_variant = new_tilesets
	var tilesets: Array = tilesets_variant
	for i in range(tilesets.size()):
		var entry_variant : Variant = tilesets[i]
		if !(entry_variant is Dictionary):
			entry_variant = {}
			tilesets[i] = entry_variant
		var entry: Dictionary = entry_variant
		if !entry.has("id"):
			entry["id"] = "tileset_%02d" % (i + 1)
		if !entry.has("path"):
			entry["path"] = ""
		if !entry.has("tile_size"):
			entry["tile_size"] = TILESET_DEFAULT_TILE_SIZE
		var tiles_variant : Variant = entry.get("tiles", [])
		if !(tiles_variant is Array):
			tiles_variant = []
		entry["tiles"] = tiles_variant
	return tilesets

func _update_project_from_ui() -> void:
	var project := _ensure_project_dictionary()
	project["title"] = project_title_field.text
	project["author"] = project_author_field.text
	project["version"] = project_version_field.text
	project["description"] = project_description_field.text

func _update_visuals_from_ui() -> void:
	var visuals := _ensure_visuals_dictionary()
	visuals["zoom"] = visuals_zoom_field.value

func _update_gameplay_from_ui() -> void:
	var gameplay := _ensure_gameplay_dictionary()
	gameplay["can_pass_turn"] = gameplay_can_pass_turn_field.button_pressed

func _refresh_tilesets_ui() -> void:
	var tilesets := _ensure_tilesets_array()
	for child in tileset_list_container.get_children():
		child.queue_free()
	_tileset_buttons.clear()
	_tileset_button_group = ButtonGroup.new()
	_tileset_button_group.allow_unpress = false
	for index in range(tilesets.size()):
		var entry: Dictionary = tilesets[index]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _tileset_button_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = _get_tileset_button_label(entry, index)
		button.pressed.connect(_on_tileset_button_pressed.bind(index))
		tileset_list_container.add_child(button)
		_tileset_buttons.append(button)
	if tilesets.is_empty():
		_current_tileset_index = -1
		tileset_remove_button.disabled = true
		_show_tileset_detail(false)
		_clear_tileset_fields()
	else:
		tileset_remove_button.disabled = false
		if _current_tileset_index < 0 or _current_tileset_index >= tilesets.size():
			_current_tileset_index = 0
		_select_tileset(_current_tileset_index)

func _on_tileset_button_pressed(index: int) -> void:
	if _suppress_tileset_button_signal or _syncing_properties:
		return
	if index < 0 or index >= _tileset_buttons.size():
		return
	var button := _tileset_buttons[index]
	if button == null or !button.button_pressed:
		return
	_select_tileset(index)

func _select_tileset(index: int) -> void:
	var tilesets := _ensure_tilesets_array()
	if tilesets.is_empty():
		_current_tileset_index = -1
		_show_tileset_detail(false)
		_clear_tileset_fields()
		return
	var clamped_index := clampi(index, 0, tilesets.size() - 1)
	_current_tileset_index = clamped_index
	_show_tileset_detail(true)
	tileset_remove_button.disabled = false
	var previous_sync := _syncing_properties
	_syncing_properties = true
	_suppress_tileset_button_signal = true
	for i in range(_tileset_buttons.size()):
		var button := _tileset_buttons[i]
		if button != null:
			button.button_pressed = (i == clamped_index)
	_suppress_tileset_button_signal = false
	var tileset: Dictionary = tilesets[clamped_index]
	tileset_id_field.text = str(tileset.get("id", ""))
	tileset_path_field.text = str(tileset.get("path", ""))
	tileset_tile_size_field.value = int(tileset.get("tile_size", TILESET_DEFAULT_TILE_SIZE))
	_refresh_tileset_tiles_list(tileset)
	_syncing_properties = previous_sync

func _clear_tileset_fields() -> void:
	var previous_sync := _syncing_properties
	_syncing_properties = true
	tileset_id_field.text = ""
	tileset_path_field.text = ""
	tileset_tile_size_field.value = TILESET_DEFAULT_TILE_SIZE
	tileset_tiles_list.clear()
	_syncing_properties = previous_sync

func _show_tileset_detail(show: bool) -> void:
	tileset_form.visible = show
	tileset_empty_label.visible = !show
	_set_tileset_fields_editable(show)

func _set_tileset_fields_editable(enabled: bool) -> void:
	tileset_id_field.editable = enabled
	tileset_path_field.editable = enabled
	tileset_browse_button.disabled = !enabled
	tileset_tile_size_field.editable = enabled
	tileset_tiles_hint.visible = enabled

func _refresh_tileset_button_labels() -> void:
	var tilesets := _ensure_tilesets_array()
	for i in range(_tileset_buttons.size()):
		if i >= tilesets.size():
			break
		var button := _tileset_buttons[i]
		if button == null:
			continue
		button.text = _get_tileset_button_label(tilesets[i], i)

func _refresh_tileset_tiles_list(tileset: Dictionary) -> void:
	tileset_tiles_list.clear()
	var tiles_variant : Variant = tileset.get("tiles", [])
	if tiles_variant is Array:
		for tile_entry_variant in tiles_variant:
			if tile_entry_variant is Dictionary:
				var tile_entry: Dictionary = tile_entry_variant
				var tile_id := str(tile_entry.get("id", "?"))
				var tile_type := str(tile_entry.get("type", ""))
				if tile_type.is_empty():
					tileset_tiles_list.add_item(tile_id)
				else:
					tileset_tiles_list.add_item("%s (%s)" % [tile_id, tile_type])

func _get_tileset_button_label(tileset: Dictionary, index: int) -> String:
	var raw_id := str(tileset.get("id", ""))
	if raw_id.is_empty():
		return "Tileset %d" % (index + 1)
	return raw_id

func _set_current_tileset_value(key: String, value: Variant) -> void:
	var tilesets := _ensure_tilesets_array()
	if _current_tileset_index < 0 or _current_tileset_index >= tilesets.size():
		return
	var tileset: Dictionary = tilesets[_current_tileset_index]
	tileset[key] = value

func _on_tileset_add_button_pressed() -> void:
	var tilesets := _ensure_tilesets_array()
	var new_tileset := {
		"id": _generate_unique_tileset_id(),
		"path": "",
		"tile_size": TILESET_DEFAULT_TILE_SIZE,
		"tiles": []
	}
	tilesets.append(new_tileset)
	_current_tileset_index = tilesets.size() - 1
	_mark_dirty()
	_focus_properties_tab(tilesets_panel)
	_refresh_tilesets_ui()

func _on_tileset_remove_button_pressed() -> void:
	var tilesets := _ensure_tilesets_array()
	if _current_tileset_index < 0 or _current_tileset_index >= tilesets.size():
		return
	tilesets.remove_at(_current_tileset_index)
	_mark_dirty()
	if tilesets.is_empty():
		_current_tileset_index = -1
	else:
		_current_tileset_index = clampi(_current_tileset_index, 0, tilesets.size() - 1)
	_refresh_tilesets_ui()

func _on_tileset_id_changed(new_text: String) -> void:
	if _syncing_properties:
		return
	var trimmed := new_text.strip_edges()
	_set_current_tileset_value("id", trimmed)
	_refresh_tileset_button_labels()
	_mark_dirty()

func _on_tileset_path_changed(new_text: String) -> void:
	if _syncing_properties:
		return
	var normalized := _normalize_path(new_text.strip_edges())
	if normalized != new_text:
		var previous_sync := _syncing_properties
		_syncing_properties = true
		tileset_path_field.text = normalized
		_syncing_properties = previous_sync
	_set_current_tileset_value("path", normalized)
	_mark_dirty()

func _on_tileset_tile_size_changed(value: float) -> void:
	if _syncing_properties:
		return
	_set_current_tileset_value("tile_size", int(value))
	_mark_dirty()

func _on_tileset_browse_button_pressed() -> void:
	if tileset_path_dialog == null:
		return
	var base_dir := _get_project_base_dir()
	if base_dir != "" and DirAccess.dir_exists_absolute(base_dir):
		tileset_path_dialog.current_dir = base_dir
	tileset_path_dialog.popup_centered_ratio(0.75)

func _on_tileset_file_selected(path: String) -> void:
	var relative := _make_relative_path(path, _get_project_base_dir())
	var previous_sync := _syncing_properties
	_syncing_properties = true
	tileset_path_field.text = relative
	_syncing_properties = previous_sync
	_set_current_tileset_value("path", relative)
	_mark_dirty()

func _generate_unique_tileset_id() -> String:
	var tilesets := _ensure_tilesets_array()
	var existing_ids := {}
	for entry_variant in tilesets:
		if entry_variant is Dictionary:
			existing_ids[str((entry_variant as Dictionary).get("id", ""))] = true
	var index := tilesets.size() + 1
	while true:
		var candidate := "tileset_%02d" % index
		if !existing_ids.has(candidate):
			return candidate
		index += 1

	push_error("Couldn't generate unique tileset!")
	return ""

func _normalize_path(path: String) -> String:
	return path.replace("\\", "/")

func _make_relative_path(target_path: String, base_dir: String) -> String:
	var normalized_target := _normalize_path(target_path)
	var normalized_base := _normalize_path(base_dir)
	if normalized_base.is_empty():
		return normalized_target
	if !normalized_base.ends_with("/"):
		normalized_base += "/"
	var lower_target := normalized_target.to_lower()
	var lower_base := normalized_base.to_lower()
	if lower_target.begins_with(lower_base):
		var relative := normalized_target.substr(normalized_base.length(), normalized_target.length() - normalized_base.length())
		return relative
	return normalized_target

func _get_project_base_dir() -> String:
	return project_data_path.get_base_dir()

func _on_visuals_zoom_changed(_value: float) -> void:
	if _syncing_properties:
		return
	_mark_dirty()

func _on_gameplay_can_pass_turn_toggled(_pressed: bool) -> void:
	if _syncing_properties:
		return
	_mark_dirty()
