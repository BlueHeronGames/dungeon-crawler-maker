extends CanvasLayer

## Displays the player's current health in the corner of the screen.
class_name PlayerHUD

@export var background_color: Color = Color(0.05, 0.05, 0.08, 0.8)
@export var border_color: Color = Color(0.4, 0.6, 0.8, 1.0)
@export var text_color: Color = Color(0.95, 0.95, 0.95, 1.0)

var _panel: Panel
var _label: Label
var _player: Player

func _ready() -> void:
	_ensure_ui()
	_update_health_text(0, 0)

func set_player(player: Player) -> void:
	if _player and _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.disconnect(_on_player_health_changed)
	_player = player
	if _player:
		_player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(_player.current_hp, _player.max_hp)
	else:
		_update_health_text(0, 0)

func _ensure_ui() -> void:
	if _panel:
		return

	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 16
	_panel.offset_top = 16
	_panel.custom_minimum_size = Vector2(170, 48)
	
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.35)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.anchor_left = 0.0
	_label.anchor_top = 0.0
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 12
	_label.offset_top = 10
	_label.offset_right = -12
	_label.offset_bottom = -10
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_font_size_override("font_size", 22)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel.add_child(_label)

func _on_player_health_changed(current: int, max: int) -> void:
	_update_health_text(current, max)

func _update_health_text(current: int, max: int) -> void:
	if not _label:
		return
	if max <= 0:
		_label.text = "HP: --"
		return
	_label.text = "HP: %d / %d" % [max(0, current), max]
