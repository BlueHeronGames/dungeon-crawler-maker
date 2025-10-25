extends CanvasLayer

## Simple inventory display overlay showing consumable items with number keys.
class_name InventoryUI

@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var header_color: Color = Color(0.8, 0.8, 0.2, 1.0)

var _panel: Panel
var _label: Label
var _player: Player
var _is_visible: bool = false

func _ready() -> void:
	_ensure_ui()
	_ensure_inventory_action()
	set_visible(false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_visibility()

func set_player(player: Player) -> void:
	_player = player

func toggle_visibility() -> void:
	_is_visible = not _is_visible
	set_to_visible(_is_visible)
	if _is_visible:
		_update_inventory_display()

func set_to_visible(visible: bool) -> void:
	_is_visible = visible
	_ensure_ui()
	_panel.visible = visible

func _update_inventory_display() -> void:
	_ensure_ui()
	if not _player:
		_label.text = "No player reference"
		return
	
	var consumables := _player.get_consumable_items()
	if consumables.is_empty():
		_label.text = "INVENTORY\n\nNo consumable items."
		return
	
	var text := "INVENTORY\n\nConsumables:\n"
	for i in range(consumables.size()):
		var item : Dictionary = consumables[i]
		var key_num := i + 1
		if key_num <= 9:
			var item_name := str(item.get("name", "Unknown"))
			var item_data : Dictionary = item.get("data", {})
			var restore_health := int(item_data.get("restore_health", 0))
			
			text += "%d. %s" % [key_num, item_name]
			if restore_health > 0:
				text += " (restores %d health)" % restore_health
			text += "\n"
	
	text += "\nPress 1-9 to use items, I to close"
	_label.text = text

func _ensure_ui() -> void:
	if _panel == null:
		_panel = Panel.new()
		_panel.anchor_left = 0.2
		_panel.anchor_right = 0.8
		_panel.anchor_top = 0.2
		_panel.anchor_bottom = 0.8
		_panel.offset_left = 0.0
		_panel.offset_right = 0.0
		_panel.offset_top = 0.0
		_panel.offset_bottom = 0.0
		
		# Set panel style
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = background_color
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color.WHITE
		_panel.add_theme_stylebox_override("panel", style_box)
		
		add_child(_panel)
	
	if _label == null:
		_label = Label.new()
		_label.anchor_left = 0.0
		_label.anchor_right = 1.0
		_label.anchor_top = 0.0
		_label.anchor_bottom = 1.0
		_label.offset_left = 16
		_label.offset_right = -16
		_label.offset_top = 16
		_label.offset_bottom = -16
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_label.add_theme_color_override("font_color", text_color)
		_panel.add_child(_label)

func _ensure_inventory_action() -> void:
	const ACTION := "toggle_inventory"
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
	_add_key_to_action(ACTION, KEY_I)

func _add_key_to_action(action_name: String, keycode: int) -> void:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	input_event.keycode = keycode
	InputMap.action_add_event(action_name, input_event)
