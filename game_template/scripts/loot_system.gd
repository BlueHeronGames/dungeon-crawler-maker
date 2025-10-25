extends RefCounted

## Handles loot drop calculation and spawning from monster deaths.
class_name LootSystem

var _rng := RandomNumberGenerator.new()
var _item_definitions: Dictionary = {}

func _init() -> void:
	_rng.randomize()

func set_config(config: GameConfig) -> void:
	if config == null:
		push_warning("LootSystem: Missing GameConfig; loot drops disabled.")
		_item_definitions = {}
		return
	_item_definitions = config.get_item_definitions()

func roll_loot(loot_table: Array) -> String:
	if loot_table.is_empty():
		return ""
	
	# Calculate total probability (min 1.0)
	var total_prob := 0.0
	for entry in loot_table:
		if entry is Dictionary:
			var prob := float(_get_probability(entry))
			total_prob += prob
	
	total_prob = max(1.0, total_prob)
	
	# Roll against normalized probabilities
	var roll := _rng.randf() * total_prob
	var cumulative := 0.0
	
	for entry in loot_table:
		if not (entry is Dictionary):
			continue
		
		var item_name := str(entry.get("name", ""))
		var prob := float(_get_probability(entry))
		
		cumulative += prob
		if roll <= cumulative and not item_name.is_empty():
			return item_name
	
	return ""

func get_item_data(item_name: String) -> Dictionary:
	if _item_definitions.has(item_name):
		var data = _item_definitions[item_name]
		if data is Dictionary:
			var result := (data as Dictionary).duplicate(true)
			result["id"] = item_name
			return result
	return {}

func _get_probability(entry: Dictionary) -> float:
	if entry.has("probability"):
		return float(entry.get("probability"))
	return float(entry.get("Probability", 0.0))
