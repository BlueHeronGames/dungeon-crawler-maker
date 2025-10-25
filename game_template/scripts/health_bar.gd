extends Control

## Displays a health bar above an entity when they've taken damage.
class_name HealthBar

@export var bar_width: int = 32
@export var bar_height: int = 4
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var health_color: Color = Color(0.8, 0.2, 0.2)

var _entity: Entity = null
var _is_visible_override: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(bar_width, bar_height)
	visible = false
	z_index = 100  # Ensure health bars render above other monsters
	z_as_relative = false  # Use absolute z-index, not relative to parent

func _draw() -> void:
	if _entity == null:
		return
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), background_color)
	
	# Draw health
	var ratio := _entity.get_hp_ratio()
	var health_width := bar_width * ratio
	if health_width > 0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(health_width, bar_height)), health_color)

func attach_to_entity(entity: Entity) -> void:
	_entity = entity
	if _entity:
		_entity.tree_exiting.connect(_on_entity_removed)
		if not _entity.health_changed.is_connected(_on_entity_health_changed):
			_entity.health_changed.connect(_on_entity_health_changed)
		update_display()
	queue_redraw()

func update_display() -> void:
	if _entity == null:
		visible = false
		return
	
	# Only show if entity has taken damage
	var has_damage := _entity.current_hp < _entity.max_hp
	visible = has_damage or _is_visible_override
	queue_redraw()

func _on_entity_removed() -> void:
	_entity = null
	visible = false

func _on_entity_health_changed(_current: int, _max: int) -> void:
	update_display()
