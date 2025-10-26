extends Control

@onready var export_button: Button = %ExportButton
@onready var run_button: Button = %RunButton
@onready var project_path_label: Label = %ProjectPathLabel
@onready var game_data_editor: TextEdit = %GameDataEditor
@onready var status_dialog: AcceptDialog = %StatusDialog
@onready var error_dialog: AcceptDialog = %ErrorDialog

var project_data_path := ""
var _return_to_picker_on_error := false

func _ready() -> void:
	export_button.pressed.connect(_on_export_button_pressed)
	run_button.pressed.connect(_on_run_button_pressed)
	error_dialog.confirmed.connect(_on_error_dialog_confirmed)
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
	game_data_editor.text = file.get_as_text()
	file.close()

func _on_export_button_pressed() -> void:
	if !_save_game_data():
		return
	_show_status("Export complete! (placeholder)")

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
	var raw_text := game_data_editor.text
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		_show_error("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	var file := FileAccess.open(project_data_path, FileAccess.WRITE)
	if file == null:
		_show_error("Unable to save game_data.json for export.")
		return false
	file.store_string(raw_text)
	file.close()
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
