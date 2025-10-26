extends RefCounted

## Builds a TileSet for the dungeon based on tileset configuration.
class_name DungeonTilesetBuilder

static func build(tileset_info: Dictionary, fallback_tile_size: int) -> Dictionary:
	var result := {
		"tile_set": null,
		"tile_size": fallback_tile_size,
		"atlas_source_id": -1,
		"tile_coords_by_type": {},
		"warnings": []
	}

	if tileset_info.is_empty():
		result["warnings"].append("DungeonMap: No tileset information provided; generation will render empty.")
		return result

	var tile_path := str(tileset_info.get("path", ""))
	if tile_path.is_empty():
		result["warnings"].append("DungeonMap: Tileset path missing in configuration.")
		return result

	if not tile_path.begins_with("res://"):
		tile_path = "res://" + tile_path

	var tile_size:int = int(tileset_info.get("tile_size", fallback_tile_size))
	var texture: Texture2D = load(tile_path)
	if texture == null:
		result["warnings"].append("DungeonMap: Failed to load tileset texture at %s" % tile_path)
		return result

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(tile_size, tile_size)

	var new_tileset := TileSet.new()
	new_tileset.tile_size = Vector2i(tile_size, tile_size)
	var atlas_source_id := new_tileset.add_source(atlas)

	var coords_by_type := _register_tile_definitions(tileset_info.get("tiles", []), atlas, texture, tile_size)
	result["tile_set"] = new_tileset
	result["tile_size"] = tile_size
	result["atlas_source_id"] = atlas_source_id
	result["tile_coords_by_type"] = coords_by_type
	return result

static func _register_tile_definitions(tile_definitions: Variant, atlas: TileSetAtlasSource, texture: Texture2D, tile_size: int) -> Dictionary:
	var coords_by_type: Dictionary = {}
	var tex_size := texture.get_size()
	var columns:int = max(1, int(tex_size.x) / tile_size)

	if tile_definitions is Array and tile_definitions.size() > 0:
		for tile_def in tile_definitions:
			if not (tile_def is Dictionary):
				continue

			var index := int(tile_def.get("id", -1))
			var type_name := str(tile_def.get("type", "")).to_lower()
			if index < 0 or type_name.is_empty():
				continue

			var coords := Vector2i(index % columns, index / columns)
			if not atlas.has_tile(coords):
				atlas.create_tile(coords)

			coords_by_type[type_name] = coords

	if not coords_by_type.has("floor"):
		var fallback := Vector2i.ZERO
		if not atlas.has_tile(fallback):
			atlas.create_tile(fallback)
		coords_by_type["floor"] = fallback

	return coords_by_type
