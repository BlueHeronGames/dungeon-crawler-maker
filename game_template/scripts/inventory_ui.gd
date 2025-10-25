extends CanvasLayer

## Modern inventory display overlay with styled UI elements.
class_name InventoryUI

@export var panel_padding: int = 20
@export var item_spacing: int = 8
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.95)
@export var border_color: Color = Color(0.4, 0.6, 0.8, 1.0)
@export var header_color: Color = Color(0.9, 0.85, 0.5, 1.0)
@export var text_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var item_bg_color: Color = Color(0.2, 0.25, 0.3, 0.8)
@export var item_hover_color: Color = Color(0.3, 0.4, 0.5, 0.9)

var _container: Control
var _header_label: Label
var _items_container: VBoxContainer
var _player: Player
var _is_visible: bool = false

func _ready() -> void:
	print("InventoryUI _ready() called")
	_ensure_ui()
	_ensure_inventory_action()
	set_to_visible(false)
	print("InventoryUI initialized, visible = ", _is_visible)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		print("Inventory toggle pressed!")
		toggle_visibility()

func set_player(player: Player) -> void:
	_player = player
	print("InventoryUI player set: ", _player)

func toggle_visibility() -> void:
	_is_visible = not _is_visible
	print("Toggling inventory visibility to: ", _is_visible)
	set_to_visible(_is_visible)
	if _is_visible:
		_update_inventory_display()

func set_to_visible(visible: bool) -> void:
	_is_visible = visible
	_ensure_ui()
	_container.visible = visible

func refresh_display() -> void:
	# Refresh the inventory display without changing visibility
	if _is_visible:
		_update_inventory_display()

func _update_inventory_display() -> void:
	_ensure_ui()
	if not _player:
		_header_label.text = "INVENTORY"
		_clear_items()
		_add_empty_message("No player reference")
		return
	
	var consumables := _player.get_consumable_items()
	_header_label.text = "INVENTORY"
	_clear_items()
	
	if consumables.is_empty():
		_add_empty_message("No consumable items")
		return
	
	# Add each item as a styled panel
	for i in range(consumables.size()):
		var item : Dictionary = consumables[i]
		var key_num := i + 1
		if key_num <= 9:
			_add_item_entry(key_num, item)
	
	# Add footer hint
	_add_footer_hint()

func _clear_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

func _add_empty_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 60)
	_items_container.add_child(label)

func _add_item_entry(key_num: int, item: Dictionary) -> void:
	var item_name := str(item.get("name", "Unknown"))
	var item_data : Dictionary = item.get("data", {})
	var quantity := int(item.get("quantity", 1))
	var restore_health := int(item_data.get("restore_health", 0))
	
	# Create item panel
	var item_panel := Panel.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = item_bg_color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = border_color.darkened(0.3)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	item_panel.add_theme_stylebox_override("panel", style_box)
	item_panel.custom_minimum_size = Vector2(0, 50)
	
	# Create HBoxContainer for horizontal layout
	var hbox := HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	item_panel.add_child(hbox)
	
	# Key number badge
	var key_label := Label.new()
	key_label.text = "[%d]" % key_num
	key_label.add_theme_color_override("font_color", header_color)
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.custom_minimum_size = Vector2(50, 0)
	hbox.add_child(key_label)
	
	# Item info container
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Item name + quantity
	var name_label := Label.new()
	var name_text := item_name.capitalize()
	if quantity > 1:
		name_text += " x%d" % quantity
	name_label.text = name_text
	name_label.add_theme_color_override("font_color", text_color)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Item effect
	if restore_health > 0:
		var effect_label := Label.new()
		effect_label.text = "↻ Restores %d health" % restore_health
		effect_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1.0))
		effect_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(effect_label)
	
	_items_container.add_child(item_panel)

func _add_footer_hint() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	_items_container.add_child(spacer)
	
	var hint_label := Label.new()
	hint_label.text = "Press [1-9] to use • [I] to close"
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_items_container.add_child(hint_label)

func _ensure_ui() -> void:
	if _container == null:
		# Main container
		_container = Control.new()
		_container.anchor_left = 0.0
		_container.anchor_right = 1.0
		_container.anchor_top = 0.0
		_container.anchor_bottom = 1.0
		_container.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_container)
		
		# Semi-transparent background overlay
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		_container.add_child(overlay)
		
		# Center panel
		var center_container := CenterContainer.new()
		center_container.anchor_right = 1.0
		center_container.anchor_bottom = 1.0
		_container.add_child(center_container)
		
		var main_panel := Panel.new()
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = background_color
		panel_style.border_width_left = 3
		panel_style.border_width_right = 3
		panel_style.border_width_top = 3
		panel_style.border_width_bottom = 3
		panel_style.border_color = border_color
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		panel_style.shadow_size = 8
		panel_style.shadow_color = Color(0, 0, 0, 0.5)
		main_panel.add_theme_stylebox_override("panel", panel_style)
		main_panel.custom_minimum_size = Vector2(500, 400)
		center_container.add_child(main_panel)
		
		# Main VBox
		var main_vbox := VBoxContainer.new()
		main_vbox.anchor_left = 0.0
		main_vbox.anchor_right = 1.0
		main_vbox.anchor_top = 0.0
		main_vbox.anchor_bottom = 1.0
		main_vbox.offset_left = panel_padding
		main_vbox.offset_right = -panel_padding
		main_vbox.offset_top = panel_padding
		main_vbox.offset_bottom = -panel_padding
		main_panel.add_child(main_vbox)
		
		# Header
		_header_label = Label.new()
		_header_label.text = "INVENTORY"
		_header_label.add_theme_color_override("font_color", header_color)
		_header_label.add_theme_font_size_override("font_size", 28)
		_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_header_label.custom_minimum_size = Vector2(0, 40)
		main_vbox.add_child(_header_label)
		
		# Separator
		var separator := HSeparator.new()
		separator.add_theme_constant_override("separation", 1)
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = border_color
		separator.add_theme_stylebox_override("separator", sep_style)
		main_vbox.add_child(separator)
		
		# Spacer
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		main_vbox.add_child(spacer)
		
		# Scroll container for items
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		main_vbox.add_child(scroll)
		
		# Items container
		_items_container = VBoxContainer.new()
		_items_container.add_theme_constant_override("separation", item_spacing)
		_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_items_container)

func _ensure_inventory_action() -> void:
	const ACTION := "toggle_inventory"
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		print("Created toggle_inventory action")
	_add_key_to_action(ACTION, KEY_I)
	print("Bound I key to toggle_inventory action")

func _add_key_to_action(action_name: String, keycode: int) -> void:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	input_event.keycode = keycode
	InputMap.action_add_event(action_name, input_event)
