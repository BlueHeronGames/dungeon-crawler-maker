# Dungeon Crawler Game Features

## Implemented Systems

### 1. Monster Health Bars
- Health bars appear above monsters when they take damage
- Automatically hide when at full health
- Red health bar with gray background
- Positioned above monster sprites

**Classes:**
- `HealthBar` (scripts/health_bar.gd)
- Attached to Monster scenes

### 2. Inventory System
- Players can carry items in an inventory array
- Each item stores name and data (type, effects, etc.)
- Support for consumable items with health restoration

**Classes:**
- `Player.inventory` - stores picked up items
- `Player.add_item_to_inventory()` - adds items
- `Player.get_inventory_items()` - retrieves inventory

### 3. Item Pickup & Drop System
- Monsters drop items based on loot tables when defeated
- Items spawn as visual nodes on the dungeon floor
- Players see "You see a(n) X" message when standing on items
- Pick up items with **G** or **.** (period) key

**Classes:**
- `LootSystem` (scripts/loot_system.gd) - handles loot rolling
- `TurnManager` - manages item drops and pickup
- Items defined in game_data.json

### 4. Consumable Item Usage
- Press number keys **1-9** to use consumable items from inventory
- Consumables restore health based on their stats
- Shows healing message in console
- Items are removed from inventory after use

**Controls:**
- **1-9**: Use consumable item in that slot
- **I**: Open/close inventory UI

**Classes:**
- `Player.use_consumable_item()` - consumes items
- `Player.get_consumable_items()` - filters consumables
- `Entity.restore_health()` - applies healing

### 5. Inventory UI
- Press **I** to toggle inventory display
- Shows all consumable items with their effects
- Displays which number key to press for each item
- Modal overlay with semi-transparent background

**Classes:**
- `InventoryUI` (scripts/inventory_ui.gd)
- Scene: scenes/inventory_ui.tscn

### 6. Message Console
- Persistent console at bottom of screen
- Shows contextual messages:
  - "You see a(n) X" when stepping on items
  - "You pick up the X" when collecting items
  - "You consume the X and restore Y health" when using items
  - Combat and movement feedback

**Classes:**
- `MessageConsole` (scripts/message_console.gd)
- Always visible at bottom of game screen

## Game Data Configuration

### Items (game_data.json)

```json
"items": {
    "goblin meat": {
        "type": "consumable",
        "restore_health": 50
    }
}
```

### Monster Loot Tables

```json
"monsters": {
    "goblin": {
        "loot_table": [
            { "name": "goblin meat", "probability": 0.25 }
        ]
    }
}
```

## Controls Summary

| Key | Action |
|-----|--------|
| Arrow Keys / WASD | Move player |
| G or . (period) | Pick up item |
| I | Open/Close inventory |
| 1-9 | Use consumable item |

## Technical Notes

### Entity Base Class
All creatures (Player, Monster) extend the `Entity` class which provides:
- Health management (current_hp, max_hp)
- Damage calculation with defense
- Health restoration
- Movement tweening
- Combat stats (attack, defense)

### Turn-Based System
- Player actions trigger a turn
- Monsters move/act after player
- Using consumable items consumes a turn
- Picking up items is instant (no turn)

### Item System Architecture
1. **LootSystem** - rolls loot from probability tables
2. **TurnManager** - spawns item drops, tracks floor items
3. **Player** - stores inventory, handles consumption
4. **InventoryUI** - displays items to player
5. **MessageConsole** - provides feedback

## Future Enhancements
- Equipment items (weapons, armor)
- Stackable consumables
- Item tooltips with detailed info
- Inventory sorting/organization
- Drop items from inventory
- Different consumable types (mana, buffs, etc.)
