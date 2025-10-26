# Tileset Configuration Guide

This guide explains how to configure tilesets in your dungeon crawler game using `game_data.json`.

## Tileset Structure

Tilesets are defined in the `tilesets` array within `game_data.json`. The first tileset in the array is used as the primary tileset for the dungeon.

### Basic Tileset Definition

```json
{
  "tilesets": [
    {
      "name": "dungeon",
      "image_path": "assets/images/tiles/dungeon_tileset.png",
      "tile_size": 32,
      "tiles": {
        "floor": [0, 0],
        "wall": [1, 0],
        "filler": [2, 0]
      }
    }
  ]
}
```

## Required Properties

### `name` (string)
A human-readable name for the tileset. Used for identification and debugging.

**Example:**
```json
"name": "dungeon"
```

### `image_path` (string)
Relative path to the tileset image from the project root. The image should be in PNG format with each tile arranged in a grid.

**Example:**
```json
"image_path": "assets/images/tiles/dungeon_tileset.png"
```

### `tile_size` (integer)
The width and height of each tile in pixels. All tiles in the tileset must be square and the same size.

**Common values:** `16`, `32`, `48`, `64`

**Example:**
```json
"tile_size": 32
```

### `tiles` (object)
A dictionary mapping tile type names to their coordinates in the tileset image.

## Tile Types

The game recognizes three special tile types. Each type determines how and where tiles are painted in the dungeon.

### `floor` (required)
Painted on all walkable cells (rooms and corridors).

**Coordinates:** `[column, row]` where `[0, 0]` is the top-left tile in the tileset image.

**Example:**
```json
"floor": [0, 0]
```

**Usage:** These tiles represent areas where the player and monsters can walk.

### `wall` (required)
Painted on non-walkable cells that are adjacent to walkable cells (room borders).

**Example:**
```json
"wall": [1, 0]
```

**Usage:** These tiles form the boundaries of rooms and corridors, providing visual separation between walkable and non-walkable areas.

### `filler` (optional)
Painted on all remaining empty space—non-walkable cells that are NOT adjacent to any room or corridor.

**Example:**
```json
"filler": [2, 0]
```

**Usage:** These tiles fill the vast empty space outside of rooms, often representing void, deep darkness, or solid rock. If not specified, these cells remain empty/transparent.

## Tile Painting Order

The dungeon map paints tiles in three passes:

1. **Floor tiles:** All walkable cells
2. **Wall tiles:** Non-walkable cells adjacent to walkable cells
3. **Filler tiles:** Remaining non-walkable cells (not adjacent to walkable cells)

This ensures proper layering and visual hierarchy.

## Coordinate System

Tile coordinates use a `[column, row]` format where:
- **Column (X):** 0-indexed position from left to right
- **Row (Y):** 0-indexed position from top to bottom

### Example Tileset Layout

For a tileset image with this arrangement:
```
[Floor] [Wall] [Filler]
[Door]  [Trap] [Chest]
```

The coordinates would be:
```json
"tiles": {
  "floor": [0, 0],
  "wall": [1, 0],
  "filler": [2, 0]
}
```

## Complete Example

```json
{
  "tilesets": [
    {
      "name": "dungeon",
      "image_path": "assets/images/tiles/dungeon_tileset.png",
      "tile_size": 32,
      "tiles": {
        "floor": [0, 0],
        "wall": [1, 0],
        "filler": [2, 0]
      }
    }
  ],
  "config": {
    "zoom": 2.0
  }
}
```

## Image Requirements

- **Format:** PNG with transparency support
- **Grid alignment:** Tiles must be perfectly aligned in a grid
- **No spacing:** Tiles should be directly adjacent with no gaps or padding
- **Consistent size:** All tiles must be exactly `tile_size × tile_size` pixels

## Common Issues

### Tiles Not Appearing
- Verify `image_path` is correct relative to project root
- Ensure image is in the `assets` folder of your project
- Check that tile coordinates don't exceed the image dimensions

### Incorrect Tile Placement
- Verify coordinates use `[column, row]` format (not `[row, column]`)
- Remember coordinates are 0-indexed
- Check that `tile_size` matches your actual tile dimensions

### Missing Filler
- The `filler` tile type is optional
- If not defined, empty space will remain transparent
- Add `filler` to fill the entire map background

## Related Files

- **Configuration:** `game_data.json`
- **Tile Painting Logic:** `game_template/scripts/dungeon_map.gd`
- **Tileset Building:** `game_template/scripts/dungeon_tileset_builder.gd`

## Tips

1. **Start simple:** Begin with just floor and wall tiles
2. **Test early:** Run your game after adding a tileset to verify it works
3. **Use distinct tiles:** Make floor, wall, and filler visually different for debugging
4. **Consider zoom:** The `config.zoom` setting affects how large tiles appear on screen
