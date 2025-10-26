extends Control

const RECENT_PROJECTS_PATH := "user://recent_projects.cfg"
const PROJECT_SECTION := "projects"
const PROJECT_KEY := "paths"
const MAX_RECENT_PROJECTS := 10
const DEFAULT_GAME_DATA_PATHS := [
	"res://editor/data/default_game_data.json",
	"res://game_template/game_data.json"
]
const JSON_INDENT := "\t"

@onready var project_list: ItemList = %ProjectList
@onready var load_button: Button = %LoadButton
@onready var new_button: Button = %NewButton
@onready var file_dialog: FileDialog = %GameDataFileDialog
@onready var new_project_dialog: FileDialog = %NewProjectDialog
@onready var notification_dialog: AcceptDialog = %NotificationDialog
@onready var error_dialog: AcceptDialog = %ErrorDialog

var recent_projects: Array[String] = []

func _ready() -> void:
	load_button.pressed.connect(_on_load_button_pressed)
	new_button.pressed.connect(_on_new_button_pressed)
	project_list.item_activated.connect(_on_project_item_activated)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	new_project_dialog.dir_selected.connect(_on_new_project_dir_selected)
	_load_recent_projects()
	_populate_project_list()

func _load_recent_projects() -> void:
	recent_projects.clear()
	var config := ConfigFile.new()
	var err := config.load(RECENT_PROJECTS_PATH)
	if err != OK:
		return
	var stored_variant : Array = config.get_value(PROJECT_SECTION, PROJECT_KEY, [])
	var stored_paths: Array = []
	if stored_variant is Array:
		stored_paths = stored_variant
		for entry in stored_paths:
			if entry is String and FileAccess.file_exists(entry):
				recent_projects.append(entry)
	if recent_projects.size() < stored_paths.size():
		_save_recent_projects()

func _populate_project_list() -> void:
	project_list.clear()
	for path in recent_projects:
		var display_text := _format_project_display(path)
		var index := project_list.add_item(display_text)
		project_list.set_item_metadata(index, path)

func _format_project_display(path: String) -> String:
	var project_dir := path.get_base_dir()
	var dir_name := project_dir.get_file()
	if dir_name.is_empty():
		dir_name = project_dir
	return "%s (%s)" % [dir_name, project_dir]

func _on_load_button_pressed() -> void:
	_open_file_dialog()

func _on_new_button_pressed() -> void:
	_open_new_project_dialog()

func _on_project_item_activated(index: int) -> void:
	var path : Variant = project_list.get_item_metadata(index)
	if typeof(path) == TYPE_STRING:
		_attempt_project_load(path)

func _open_file_dialog() -> void:
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
	file_dialog.current_file = "game_data.json"
	file_dialog.popup_centered_ratio(0.7)

func _on_file_dialog_file_selected(path: String) -> void:
	_attempt_project_load(path)

func _open_new_project_dialog() -> void:
	new_project_dialog.access = FileDialog.ACCESS_FILESYSTEM
	new_project_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	new_project_dialog.popup_centered_ratio(0.7)

func _on_new_project_dir_selected(dir_path: String) -> void:
	_create_new_project(dir_path)

func _attempt_project_load(path: String) -> void:
	if !_is_valid_game_data_path(path):
		_dismiss_selection_dialogs()
		_show_error("Please select a valid game_data.json file.")
		return
	if !FileAccess.file_exists(path):
		_dismiss_selection_dialogs()
		_show_error("Selected file could not be found.")
		return
	_add_recent_project(path)
	_dismiss_selection_dialogs()
	_show_success(path)

func _is_valid_game_data_path(path: String) -> bool:
	return path.get_file().to_lower() == "game_data.json"

func _add_recent_project(path: String) -> void:
	# Keep the list ordered with the most recent project at the top.
	recent_projects.erase(path)
	recent_projects.insert(0, path)
	if recent_projects.size() > MAX_RECENT_PROJECTS:
		recent_projects.resize(MAX_RECENT_PROJECTS)
	_save_recent_projects()
	_populate_project_list()

func _save_recent_projects() -> void:
	var config := ConfigFile.new()
	config.set_value(PROJECT_SECTION, PROJECT_KEY, recent_projects)
	var err := config.save(RECENT_PROJECTS_PATH)
	if err != OK:
		push_warning("Failed to save recent projects: %s" % err)

func _dismiss_selection_dialogs() -> void:
	if file_dialog.visible:
		file_dialog.hide()
	if new_project_dialog.visible:
		new_project_dialog.hide()

func _create_new_project(dir_path: String) -> void:
	if dir_path.is_empty():
		_show_error("Please choose a folder for the new project.")
		return
	if !DirAccess.dir_exists_absolute(dir_path):
		_show_error("Unable to open the selected folder.")
		return
	var target_path := dir_path.path_join("game_data.json")
	if FileAccess.file_exists(target_path):
		_show_error("The selected folder already contains a game_data.json file.")
		return
	var template_data := _load_template_game_data()
	if template_data.is_empty():
		_show_error("Unable to locate template game_data.json contents.")
		return
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		_show_error("Failed to create game_data.json in the selected folder.")
		return
	file.store_string(template_data)
	file.close()
	_attempt_project_load(target_path)

func _load_template_game_data() -> String:
	for path in DEFAULT_GAME_DATA_PATHS:
		if FileAccess.file_exists(path):
			var template_file := FileAccess.open(path, FileAccess.READ)
			if template_file != null:
				var contents := template_file.get_as_text()
				template_file.close()
				if !contents.is_empty():
					return contents
	return ""

func _show_success(path: String) -> void:
	notification_dialog.title = "Project Loaded"
	notification_dialog.dialog_text = "Congratulations! Loaded project from:\n%s" % path.get_base_dir()
	notification_dialog.call_deferred("popup_centered")

func _show_error(message: String) -> void:
	error_dialog.title = "Unable to Load"
	error_dialog.dialog_text = message
	error_dialog.call_deferred("popup_centered")
