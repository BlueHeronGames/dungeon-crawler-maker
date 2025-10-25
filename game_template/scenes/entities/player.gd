extends Entity

## Player entity handles WASD input and applies camera settings from configuration.
class_name Player

@export var step_size: float = 32.0
@export var camera_path: NodePath = NodePath("Camera2D")
@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var turn_manager_path: NodePath = NodePath("../TurnManager")

@onready var camera: Camera2D = get_node_or_null(camera_path)
@onready var _collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path)
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)
@onready var _turn_manager: TurnManager = get_node_or_null(turn_manager_path)

var _config: GameConfig
var inventory: Array = [] # Each entry is a dictionary containing item data

func _ready() -> void:
	_config = GameConfig.load_from_file()
	_apply_tile_metrics(_config.get_tile_size(int(step_size)))
	_apply_camera_settings()
	_apply_player_stats()
	_ensure_pickup_action()

func _apply_player_stats() -> void:
	max_hp = 100
	current_hp = max_hp
	attack = 15
	defense = 5

func _physics_process(_delta: float) -> void:
	if not can_accept_movement():
		return

	if _turn_manager and Input.is_action_just_pressed("pickup"):
		_turn_manager.request_item_pickup()
		return
	
	# Check for consumable item usage (keys 1-9)
	var consumables := get_consumable_items()
	for i in range(1, min(10, consumables.size() + 1)):
		var action_name := "use_item_%d" % i
		if Input.is_action_just_pressed(action_name):
			var consumable_data : Dictionary = consumables[i - 1]
			var inventory_index := int(consumable_data.get("index", -1))
			if use_consumable_item(inventory_index):
				return # Consuming an item ends the turn

	var direction := _read_movement_input()
	if direction == Vector2.ZERO:
		return

	var step_direction := Vector2i(int(sign(direction.x)), int(sign(direction.y)))
	if step_direction == Vector2i.ZERO:
		return
	if _turn_manager:
		_turn_manager.process_player_input(step_direction)

func _read_movement_input() -> Vector2:
	var horizontal := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var vertical := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var direction := Vector2(horizontal, vertical)

	if direction == Vector2.ZERO:
		return Vector2.ZERO

	# Prevent diagonal movement to preserve grid-based stepping.
	if abs(direction.x) > 0 and abs(direction.y) > 0:
		if abs(direction.x) >= abs(direction.y):
			direction.y = 0
		else:
			direction.x = 0

	return direction.normalized()

func _apply_camera_settings() -> void:
	if camera == null:
		push_warning("Player: Camera node not found; cannot apply zoom or limits.")
		return

	camera.make_current()
	var zoom_value := _config.get_zoom(1.0)
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.limit_left = 0
	camera.limit_top = 0

func configure_camera_limits(map_size: Vector2i, tile_size: int) -> void:
	if camera == null:
		return

	var width_pixels:int = max(0, map_size.x * tile_size)
	var height_pixels:int = max(0, map_size.y * tile_size)
	camera.limit_right = max(0, width_pixels - tile_size)
	camera.limit_bottom = max(0, height_pixels - tile_size)

func _apply_tile_metrics(tile_size: int) -> void:
	step_size = float(tile_size)
	if _collision_shape:
		_collision_shape.position = Vector2.ZERO # keep collisions centered on the entity
		if _collision_shape.shape is RectangleShape2D:
			var rect := _collision_shape.shape as RectangleShape2D
			var padding:float = max(1.0, tile_size * 0.05) # small inset prevents walls from blocking adjacent tiles
			rect.size = Vector2(tile_size - padding, tile_size - padding)
	if _sprite:
		var base_size := Vector2.ONE
		if _sprite.region_enabled:
			base_size = _sprite.region_rect.size
		elif _sprite.texture:
			base_size = _sprite.texture.get_size()
		if base_size.x != 0 and base_size.y != 0:
			var scale := tile_size / base_size.x
			_sprite.scale = Vector2(scale, scale)

func add_item_to_inventory(item_name: String, item_data: Dictionary) -> void:
	var entry_data := {}
	if item_data is Dictionary:
		entry_data = (item_data as Dictionary).duplicate(true)
	inventory.append({
		"name": item_name,
		"data": entry_data
	})

func get_inventory_items() -> Array:
	return inventory.duplicate(true)

func use_consumable_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false
	
	var item_entry : Dictionary = inventory[inventory_index]
	if not (item_entry is Dictionary):
		return false
	
	var item_data : Variant = item_entry.get("data", {})
	var item_type := str(item_data.get("type", ""))
	
	if item_type != "consumable":
		return false
	
	# Apply consumable effects
	var restore_health_amount := int(item_data.get("restore_health", 0))
	if restore_health_amount > 0:
		var actual_healing := restore_health(restore_health_amount)
		
		# Notify via console if available
		var turn_manager := get_node_or_null(turn_manager_path) as TurnManager
		if turn_manager and turn_manager.has_method("show_console_message"):
			var item_name := str(item_entry.get("name", "item"))
			if actual_healing > 0:
				turn_manager.show_console_message("You consume the %s and restore %d health." % [item_name, actual_healing])
			else:
				turn_manager.show_console_message("You consume the %s but you're already at full health." % item_name)
	
	# Remove item from inventory after use
	inventory.remove_at(inventory_index)
	return true

func get_consumable_items() -> Array:
	var consumables: Array = []
	for i in range(inventory.size()):
		var item_entry : Dictionary = inventory[i]
		if item_entry is Dictionary:
			var item_data : Dictionary = item_entry.get("data", {})
			if str(item_data.get("type", "")) == "consumable":
				consumables.append({
					"index": i,
					"name": item_entry.get("name", ""),
					"data": item_data
				})
	return consumables

func _ensure_pickup_action() -> void:
	const ACTION := "pickup"
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
	_add_key_to_action(ACTION, KEY_PERIOD)
	_add_key_to_action(ACTION, KEY_G)
	
	# Also set up consumable usage keys
	_ensure_consumable_actions()

func _ensure_consumable_actions() -> void:
	for i in range(1, 10):  # Support using items 1-9
		var action_name := "use_item_%d" % i
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		_add_key_to_action(action_name, KEY_0 + i)

func _add_key_to_action(action_name: String, keycode: int) -> void:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	input_event.keycode = keycode
	InputMap.action_add_event(action_name, input_event)
