extends CanvasLayer

## Lightweight console overlay for displaying player-facing text prompts.
class_name MessageConsole

@export var panel_height: int = 72
@export var horizontal_margin: int = 16

var _panel: Panel
var _label: Label

func _ready() -> void:
	_ensure_ui()
	clear_message()

func show_message(message: String) -> void:
	_ensure_ui()
	_label.text = message

func clear_message() -> void:
	_ensure_ui()
	_label.text = ""

func show_item_seen(item_name: String) -> void:
	if item_name.strip_edges().is_empty():
		clear_message()
		return
	show_message("You see a(n) %s" % item_name)

func show_item_picked_up(item_name: String) -> void:
	if item_name.strip_edges().is_empty():
		show_message("You pick something up, but it crumbles away.")
		return
	show_message("You pick up the %s." % item_name)

func _ensure_ui() -> void:
	if _panel == null:
		_panel = Panel.new()
		_panel.anchor_left = 0.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = 0.0
		_panel.offset_right = 0.0
		_panel.offset_top = -panel_height
		_panel.offset_bottom = 0.0
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_panel)
	if _label == null:
		_label = Label.new()
		_label.anchor_left = 0.0
		_label.anchor_right = 1.0
		_label.anchor_top = 0.0
		_label.anchor_bottom = 1.0
		_label.offset_left = horizontal_margin
		_label.offset_right = -horizontal_margin
		_label.offset_top = 0.0
		_label.offset_bottom = 0.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(_label)