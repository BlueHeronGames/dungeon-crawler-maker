extends Control

@onready var export_button: Button = %ExportButton
@onready var project_path_label: Label = %ProjectPathLabel
@onready var game_data_editor: TextEdit = %GameDataEditor
@onready var status_dialog: AcceptDialog = %StatusDialog
@onready var error_dialog: AcceptDialog = %ErrorDialog

var project_data_path := ""
var _return_to_picker_on_error := false

func _ready() -> void:
	export_button.pressed.connect(_on_export_button_pressed)
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
	var raw_text := game_data_editor.text
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		_show_error("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	var file := FileAccess.open(project_data_path, FileAccess.WRITE)
	if file == null:
		_show_error("Unable to save game_data.json for export.")
		return
	file.store_string(raw_text)
	file.close()
	_show_status("Export complete! (placeholder)")

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
