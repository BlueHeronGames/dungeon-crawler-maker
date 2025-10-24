# Dungeon Crawler Maker - Architecture

## Overview
A roguelike game maker that produces self-standing executables without requiring users to have Godot installed.

## High-Level Architecture Decision

### Recommended Approach: **Split Editor + Game Template**

Instead of embedding Godot editor, we recommend a cleaner separation:

1. **Editor Application** (Godot-based)
   - User-facing game maker/designer tool
   - Creates and edits game data/assets
   - Exports game definitions to a standardized format

2. **Game Template** (Godot project)
   - Standalone runtime that reads game definitions
   - Exports to executable for each platform
   - No editor dependencies

### Why NOT Embed Godot Editor?

- **Bloat**: Godot editor is 50-100MB+, most features unused
- **Complexity**: Editor APIs are not designed for embedding
- **Licensing**: While MIT-licensed, redistribution adds complexity
- **UX**: Users want a custom maker, not a generic engine
- **Updates**: Godot updates could break embedded functionality

## Detailed Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   DUNGEON CRAWLER MAKER                 │
│                     (Editor Tool)                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────┐  │
│  │  Map Designer  │  │  Asset Manager │  │  Monster  │  │
│  │   - Tiles      │  │   - Sprites    │  │   Editor  │  │
│  │   - Rooms      │  │   - Sounds     │  │   - Stats │  │
│  │   - Gen Rules  │  │   - Music      │  │   - AI    │  │
│  └────────────────┘  └────────────────┘  └───────────┘  │
│                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────┐  │
│  │  Item Editor   │  │  Class Editor  │  │  Export   │  │
│  │   - Weapons    │  │   - Player     │  │  Manager  │  │
│  │   - Armor      │  │   - Abilities  │  │           │  │
│  │   - Consumables│  │   - Progression│  │           │  │
│  └────────────────┘  └────────────────┘  └───────────┘  │
│                                                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Exports Game Definition
                       ▼
              ┌────────────────────┐
              │   game_data.json   │
              │   + assets/        │
              └────────────────────┘
                       │
                       │ Bundled with
                       ▼
┌─────────────────────────────────────────────────────────┐
│                  GAME RUNTIME TEMPLATE                  │
│                   (Godot Project)                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │              Data Loader System                    │ │
│  │  - Parses game_data.json                           │ │
│  │  - Loads custom assets                             │ │
│  │  - Initializes game rules                          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │   Dungeon     │  │    Combat     │  │   Player    │  │
│  │  Generator    │  │    System     │  │   Systems   │  │
│  │  - Proc Gen   │  │  - Turn-based │  │  - Movement │  │
│  │  - Rooms      │  │  - Damage     │  │  - Inventory│  │
│  └───────────────┘  └───────────────┘  └─────────────┘  │
│                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │      AI       │  │      UI       │  │   Save      │  │
│  │   - Monster   │  │  - Inventory  │  │   System    │  │
│  │   - Pathfind  │  │  - HUD        │  │             │  │
│  └───────────────┘  └───────────────┘  └─────────────┘  │ 
│                                                         │
└─────────────────────────────────────────────────────────┘
                       │
                       │ Export via Godot CLI
                       ▼
              ┌────────────────────┐
              │  game.exe/.app     │
              │  (Standalone)      │
              └────────────────────┘
```

## Component Details

### 1. Editor Application (DCM)

**Technology**: Godot Engine 4.x

**Structure**:
```
dcm/
├── project.godot
├── editor/
│   ├── main.tscn           # Main editor window
│   ├── map_designer/
│   │   ├── tile_palette.gd
│   │   ├── room_editor.gd
│   │   └── generator_config.gd
│   ├── entity_editors/
│   │   ├── monster_editor.gd
│   │   ├── item_editor.gd
│   │   └── class_editor.gd
│   ├── asset_browser/
│   │   └── asset_manager.gd
│   └── export/
│       ├── exporter.gd
│       └── bundler.gd
├── ui/
│   ├── themes/
│   └── widgets/
└── data/
    └── templates/          # Default game templates
```

**Key Features**:
- Custom Godot UI for intuitive game design
- Real-time preview of maps/entities
- Asset import and management
- Export to standardized JSON format
- Bundle with game template

### 2. Game Data Format

**game_data.json** - Standardized format for all game content:

```json
{
  "version": "1.0",
  "metadata": {
    "title": "My Roguelike",
    "author": "Creator Name",
    "description": "Game description"
  },
  "config": {
    "starting_class": "warrior",
    "difficulty": "normal",
    "permadeath": true
  },
  "tilesets": [
    {
      "id": "dungeon_basic",
      "path": "assets/tiles/dungeon.png",
      "tile_size": 16
    }
  ],
  "rooms": [
    {
      "id": "entrance",
      "width": 20,
      "height": 15,
      "tiles": [...],
      "spawn_rules": {...}
    }
  ],
  "monsters": [
    {
      "id": "goblin",
      "name": "Goblin",
      "sprite": "assets/monsters/goblin.png",
      "stats": {
        "hp": 20,
        "attack": 5,
        "defense": 2
      },
      "ai_type": "aggressive",
      "loot_table": [...]
    }
  ],
  "items": [...],
  "classes": [...]
}
```

### 3. Game Runtime Template

**Technology**: Godot Engine 4.x (lightweight runtime)

**Structure**:
```
game_template/
├── project.godot
├── export_presets.cfg      # Platform export configs
├── game_data.json          # Injected by editor
├── assets/                 # Injected by editor
├── src/
│   ├── main.gd
│   ├── game_loader.gd      # Parses game_data.json
│   ├── systems/
│   │   ├── dungeon_generator.gd
│   │   ├── combat_system.gd
│   │   ├── inventory_system.gd
│   │   └── save_system.gd
│   ├── entities/
│   │   ├── player.gd
│   │   ├── monster.gd
│   │   └── item.gd
│   ├── ai/
│   │   └── monster_ai.gd
│   └── ui/
│       ├── hud.tscn
│       ├── inventory_ui.tscn
│       └── main_menu.tscn
└── scenes/
    └── game.tscn           # Main game scene
```

**Key Features**:
- Data-driven: Everything loaded from game_data.json
- Modular systems for easy extension
- Generic enough to handle various roguelike styles
- Optimized for export (no editor dependencies)

## Workflow

### For You (Developer):

1. **Develop Editor** (`dcm/`)
   - Build custom UI in Godot
   - Implement game design tools
   - Create exporter

2. **Develop Game Template** (`game_template/`)
   - Build generic roguelike runtime
   - Implement data loader
   - Test with various game_data.json files

3. **Bundle for Distribution**
   - Export editor as executable
   - Include game_template folder
   - Ship with Godot export templates (headless)

### For Users:

1. **Design Game**
   - Open DCM editor
   - Create maps, monsters, items, etc.
   - Preview in editor

2. **Export Game**
   - Click "Export Game"
   - Editor copies game_template
   - Injects game_data.json + assets
   - Uses Godot CLI to export executable

3. **Distribute Game**
   - User gets standalone .exe/.app
   - No Godot installation needed
   - No DCM editor needed

## Game Template Distribution: Source vs Binary

### The Problem: Godot's Import System

You're correct - Godot **pre-processes and imports** assets:
- PNG files → `.godot/imported/` as optimized textures
- Audio files → converted formats
- Creates `.import` files with metadata
- Generates resource UIDs

This means we have **two approaches**:

### ✅ Approach 1: Ship as SOURCE (Re-import Each Time) - RECOMMENDED

**How it works:**
1. DCM ships with the game_template **source code** (GDScript files, project.godot)
2. DCM ships with Godot **headless executable** + export templates
3. When user exports their game:
   - Copy game_template source
   - Inject user's assets as **raw files** (PNG, OGG, etc.)
   - Inject game_data.json
   - Run Godot headless to **import and export** in one go

**Pros:**
- ✅ User assets are fresh-imported each time
- ✅ Supports any asset format Godot supports
- ✅ No pre-baked import conflicts
- ✅ Smaller DCM distribution (no .godot/imported folder)

**Cons:**
- ⏱️ Export takes 30-60 seconds (import + compile + export)
- 💾 Requires bundling Godot headless (~100MB)

**Implementation:**
```gdscript
# In DCM's exporter.gd
func export_game(output_path: String):
    # 1. Copy template source
    var temp_dir = "temp_export_" + str(Time.get_ticks_msec())
    DirAccess.copy_absolute("res://game_template/", temp_dir)
    
    # 2. Inject user's RAW assets
    DirAccess.copy_absolute(project.assets_dir, temp_dir + "/user_assets/")
    
    # 3. Inject game_data.json
    var file = FileAccess.open(temp_dir + "/game_data.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(game_data))
    
    # 4. Run Godot headless to import and export
    var godot_exe = "godot_headless.exe" # Bundled with DCM
    OS.execute(godot_exe, [
        "--headless",
        "--path", temp_dir,
        "--export-release", "Windows Desktop", output_path
    ])
    
    # Assets are imported during this step, then packed into PCK
```

### ⚠️ Approach 2: Ship as BINARY (Pre-exported Template)

**How it works:**
1. You pre-export game_template as an executable
2. Ship this **pre-built binary** with DCM
3. User's custom data loaded at **runtime** via user:// directory or external files
4. No re-import, no Godot needed

**Pros:**
- ⚡ Instant export (just copy files)
- 💾 Smaller DCM (no Godot headless needed)

**Cons:**
- ❌ User assets must be **pre-imported by DCM** using Godot's import API
- ❌ Complex: DCM must replicate Godot's import pipeline
- ❌ OR user assets loaded as raw files (slower, no optimization)
- ❌ Less flexible for different asset types

**Implementation:**
```gdscript
# Game template loads data at runtime
func _ready():
    # Load from external user:// directory
    var data_file = FileAccess.open("user://game_data.json", FileAccess.READ)
    var game_data = JSON.parse_string(data_file.get_as_text())
    
    # Load assets as raw Image/AudioStreamWAV (no import optimization)
    var img = Image.new()
    img.load_png_from_buffer(FileAccess.get_file_as_bytes("user://assets/monster.png"))
    var texture = ImageTexture.create_from_image(img)
```

## Recommended Export Process (Approach 1)

```
User clicks "Export" in DCM Editor
           ↓
1. Validate game data
           ↓
2. Serialize to game_data.json
           ↓
3. Copy game_template/ SOURCE to temp folder
           ↓
4. Inject game_data.json + RAW assets (PNG, OGG, etc.)
           ↓
5. Run Godot headless:
   - Imports all assets automatically
   - Exports to target platform
   godot --headless --path temp_folder --export-release "Windows Desktop" game.exe
           ↓
6. Godot creates .pck file with imported/optimized assets
           ↓
7. Present game.exe + game.pck to user (or single executable if embedded)
```

### What Gets Shipped with DCM?

```
dcm_distribution/
├── dcm_editor.exe              # Your editor
├── godot_headless.exe          # Godot headless for exporting (~100MB)
├── export_templates/           # Godot export templates
│   ├── windows_64_release.exe
│   ├── linux_64_release
│   └── macos.zip
└── game_template/              # SOURCE CODE (not pre-built)
    ├── project.godot
    ├── src/
    │   ├── main.gd
    │   ├── game_loader.gd
    │   └── ...
    ├── scenes/
    └── export_presets.cfg
```

### How Assets Flow:

```
DCM Editor (User designs game)
    ↓
User imports monster.png into DCM
    ↓ (DCM stores as raw PNG)
game_template/user_assets/monster.png (raw)
    ↓
Godot headless import (during export)
    ↓
game_template/.godot/imported/monster.png-[hash].ctex (optimized)
    ↓
Packed into game.pck
    ↓
Final game.exe reads from embedded PCK
```

## Alternative: Hybrid Approach

For **faster iterations** during development, you could support both:

1. **Quick Export** (Approach 2): Pre-built binary, data loaded externally
   - For testing/preview
   - Instant but less optimized
   
2. **Final Export** (Approach 1): Full re-import and export
   - For distribution
   - Takes time but fully optimized

This gives users fast iteration while maintaining quality for final builds.

## Technical Requirements

### Editor (DCM)
- **Godot Version**: 4.3+
- **Scripting**: GDScript (faster development) or C# (if you prefer)
- **Size**: ~200-300MB installed
- **Platforms**: Windows, macOS, Linux

### Game Template
- **Godot Version**: Same as editor (4.3+)
- **Scripting**: GDScript (smaller exports)
- **Exported Size**: 30-50MB base + assets
- **Platforms**: Windows, macOS, Linux, potentially Web

### Export Templates
- Ship Godot export templates with DCM
- Located in: `dcm/godot_templates/`
- Used for headless export

## Alternative Architectures (Considered)

### ❌ Option A: Embedded Godot Editor
**Pros**: Users edit in "real" Godot
**Cons**: 100MB+ bloat, complex, breaks on updates, poor UX

### ❌ Option B: Pure Data + Separate Engine
**Pros**: Very clean separation
**Cons**: Requires maintaining custom engine or using existing one

### ✅ Option C: Split Editor + Template (RECOMMENDED)
**Pros**: Clean, maintainable, good UX, reasonable size
**Cons**: Must develop custom editor UI

## File Size Estimates

- **DCM Editor**: 150-250MB
- **Exported Game**: 30MB + your assets
- **Distribution**: One-time download of editor

## Development Phases

### Phase 1: Core Runtime (4-6 weeks)
- Basic game template structure
- Data loader system
- Simple dungeon generation
- Player movement and basic combat
- Test with hand-written game_data.json

### Phase 2: Editor MVP (6-8 weeks)
- Main editor UI
- Basic map designer
- Simple monster/item editors
- Export functionality
- End-to-end test: Design → Export → Play

### Phase 3: Advanced Features (8-12 weeks)
- Advanced dungeon generation rules
- Complex AI behaviors
- Skill/ability system
- Save/load system
- Polished editor UX

### Phase 4: Polish & Release (4-6 weeks)
- Tutorial/documentation
- Example games
- Installer/packaging
- Testing on all platforms

## Technology Stack Summary

| Component | Technology | Language | Purpose |
|-----------|-----------|----------|---------|
| Editor UI | Godot 4.3 | GDScript | Game maker tool |
| Game Runtime | Godot 4.3 | GDScript | Plays exported games |
| Data Format | JSON | - | Game definitions |
| Export | Godot CLI | - | Build executables |

## Key Design Principles

1. **Data-Driven**: Game template reads everything from JSON
2. **Separation of Concerns**: Editor ≠ Runtime
3. **User-Friendly**: Hide Godot complexity
4. **Extensible**: Easy to add new features to template
5. **Portable**: Exported games are truly standalone

## Next Steps

1. Set up two separate Godot projects:
   - `dcm_editor/` - The maker tool
   - `game_template/` - The runtime

2. Define complete `game_data.json` schema

3. Build minimal game template that loads JSON

4. Build minimal editor that exports JSON

5. Iterate and expand features

---

**Questions to Consider:**

- What roguelike subgenre? (Traditional, action, deck-builder?)
- Turn-based or real-time?
- Target platforms priority?
- Tile-based or free movement?
- Required vs. optional features in MVP?
