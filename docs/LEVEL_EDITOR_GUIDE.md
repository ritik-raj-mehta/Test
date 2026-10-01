# Zumpa Level Editor & Obstacle Architecture Guide

Welcome to the comprehensive technical and operational guide for the **Zumpa Level Editor Plugin**, obstacle systems, registration architectures, world themes, and gameplay execution pipelines in **Zumpa Jump** (Godot 4).

---

## 1. Architecture Overview & Lifecycle

```
                     ┌───────────────────────────────┐
                     │         ObjectRegistry        │
                     │  (Scenes, Prefabs, Properties) │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
 ┌──────────────────────┐    ┌───────────────┐    ┌──────────────────────┐
 │  WorldThemeRegistry  ├───►│  Level Editor ├───►│  LevelData (.tres)   │
 │ (Themes, Skins, Tiles)│    │ (level_canvas)│    │ (Deep Cloned Models) │
 └──────────────────────┘    └───────────────┘    └──────────┬───────────┘
                                                             │
                                   ┌─────────────────────────┴─────────────────────────┐
                                   ▼                                                   ▼
                     ┌───────────────────────────┐                       ┌───────────────────────────┐
                     │   LevelLoader (Dynamic)   │                       │    Pre-Baked Scene (.tscn)│
                     │ (Mobile Runtime Spawning) │                       │ (Zero CPU Deserialization)│
                     └─────────────┬─────────────┘                       └─────────────┬─────────────┘
                                   │                                                   │
                                   └─────────────────────────┬─────────────────────────┘
                                                             ▼
                                                ┌─────────────────────────┐
                                                │   Gameplay Active Node  │
                                                │ (Player + Obstacle Loop)│
                                                └─────────────────────────┘
```

### Core Tenets & Data Isolation
1. **Per-Instance Isolation**: Multiple obstacles of the same type placed in the same scene operate with 100% independent state, speeds, delays, distances, and trajectory timers via local `_elapsed_time += delta` loops (no shared global clock).
2. **Deep-Cloned Properties**: `ObjectData.properties` are cloned with `properties.duplicate(true)` during creation, duplication, and undo/redo snapshots to prevent memory reference leakage.
3. **High-Performance O(1) Geometry Caches**: Obstacles precompute direction vectors (`_move_dir_vec`), cycle timings (`_cycle_duration`), and polygonal distances on initialization.
4. **Z-Index Visual Hierarchy**:
   - **World Terrain (`TileMapLayer`)**: Renders at `z_index = 150` (highest visibility layer in gameplay so character and obstacles move seamlessly through foreground terrain tunnels).
   - **Obstacles & Hazards**: Render between `z_index = 0` to `z_index = 100`.
   - **Player**: Renders at `z_index = 10`.
   - **Theme Background**: Renders at `z_index = -100`.

---

## 2. Level Editor Interface & Controls

The **Zumpa Level Editor** is located at `addons/zumpa_level_editor/` and integrates directly as a main-screen Godot 4 editor tab.

### Setup & Activation
1. Open Godot 4 -> **Project -> Project Settings -> Plugins**.
2. Locate **Zumpa Level Editor** and check **Enable**.
3. Click the **Level Editor** tab at the top of the Godot Editor window.

### Editor Controls & Shortcuts
| Control / Key | Action | Description |
|---|---|---|
| **`MMB` Drag (Scroll Click)** | **Pan Canvas** | Pans the editor camera smoothly across the entire level canvas |
| **`Wheel Up / Down`** | **Zoom In / Out** | Zooms smoothly from `0.15x` to `3.0x` centered on mouse cursor |
| **`Left Click`** | **Select / Move** | Selects obstacle, shows gizmos/properties in Inspector, drags position |
| **`Arrow Keys`** | **Nudge Object** | Moves selected object by 1px (or 32px grid snap step when enabled) |
| **`Shift + Arrow Keys`** | **Fast Nudge** | Moves selected object by 10px |
| **`Ctrl + D`** | **Duplicate** | Duplicates selected obstacle with offset and deep-cloned properties |
| **`Delete` / `Backspace`** | **Delete** | Removes selected obstacle from level data |
| **`Ctrl + Z`** | **Undo** | Reverts changes up to 50 deep-copy history snapshots |
| **`Ctrl + S`** | **Save Level** | Saves `.tres` resource and automatically generates/bakes `.tscn` file |
| **`Ctrl + B`** | **Bake All** | Bakes all levels in the project to `.tscn` packed scenes |
| **▶ Play Test Button** | **Test Gameplay** | Sets current level as active and runs `game_play.tscn` directly |

### Canvas Visual Overlays
- **Cyan Viewport Frame**: $1080 \times 1920$ mobile portrait boundary showing the exact in-game screen view.
- **Yellow Center Guide ($X = 540$)**: Symmetrical screen axis line.
- **Grid Snapping (32px)**: Centered on $X = 540.0$ so symmetrical obstacle placement is effortless.
- **Pixel Coordinates Tooltip**: Real-time `[X: ..., Y: ...]` display at cursor.
- **Dashed Guideline Visualizers**: Visualizes travel paths, endpoint turn-around caps, direction arrows, and delay durations directly in the editor.

---

## 3. Complete Obstacle Catalog & Configuration

### 1. `gear_path` (Path / Shape Moving Gear)
A multi-shape trajectory hazard that travels in closed geometric loops with corner pauses and variable rotation speeds.

* **Scene**: `res://game/scenes/Obstacles/PathMovingGear.tscn`
* **Controller**: `PathMovingGearController.gd`
* **Key Properties**:
  - `path_shape`: Geometric path shape (`"Diamond"`, `"Rectangle"`, `"Square"`, `"Triangle"`, `"Circle"`).
  - `path_width` & `path_height`: Bounding dimensions of the shape track in pixels.
  - `path_rotation`: Rotation angle of the whole path geometry (in degrees).
  - `move_direction`: Travel direction (`"Clockwise"`, `"Counter-Clockwise"`, `"Alternating"`).
  - `alternate_interval`: Time in seconds between direction reversals when using `Alternating` (0 = reverse after every full loop).
  - `corner_delay`: Pause duration in seconds at each corner vertex.
  - `move_speed`: Linear travel speed along the perimeter path (in pixels/sec).
  - `rotation_speed`: Self-rotation speed of the gear sprites (radians/sec).
  - `gear_count`: Number of synchronized gears spaced evenly around the loop (1 to 10).
  - `show_track_line` & `track_color`: Track rendering options.
  - `world_theme`: Auto-applied world theme texture skin.
* **Editor Visuals**: Real-time cyan trajectory shape, direction indicator arrows on segment midpoints, and red corner vertex markers.

---

### 2. `gear_m` (Moving Gear)
A linear moving gear with independent positive and negative travel distances, customizable angles, start delays, direction change delays, and multi-gear cloning.

* **Scene**: `res://game/scenes/Obstacles/MovingGear.tscn`
* **Controller**: `MovingGearController.gd`
* **Key Properties**:
  - `move_angle`: Travel direction in degrees (`0` = Right, `90` = Down, `180` = Left, `-90` = Up, or any free angle).
  - `move_dist_pos`: Distance to travel in the positive direction along `move_angle`.
  - `move_dist_neg`: Distance to travel in the negative direction along `move_angle`.
  - `move_speed`: Linear travel speed (pixels/sec).
  - `rotation_speed`: Self-rotation speed of gear sprites.
  - `start_delay`: Initial delay in seconds before movement begins upon level start.
  - `direction_change_delay` (or `delay`): Pause duration in seconds at each travel end before reversing direction.
  - `gear_count`: Number of moving gears replicated along the track (1 to 20).
  - `gear_spacing`: Distance in pixels between each replicated gear.
  - `world_theme`: Auto-applied theme gear texture.
* **Movement Dynamics**:
  - **Reverse-only (`neg_d > 0`, `pos_d == 0`)**: Starts at placed position $0$, moves in reverse to $-\text{neg\_d}$, pauses for `direction_change_delay`, and returns.
  - **Forward-only (`pos_d > 0`, `neg_d == 0`)**: Starts at placed position $0$, moves forward to $+\text{pos\_d}$, pauses, and returns.
  - **Bidirectional (`pos_d > 0`, `neg_d > 0`)**: Starts at placed position $0$, travels between $[-\text{neg\_d}, +\text{pos\_d}]$.
* **Editor Visuals**: Bright cyan dashed line with green origin circle, red end caps, yellow clone resting points, and distance/delay HUD labels.

---

### 3. `gear_with_rod` (Moving Gear with Fixed Rod)
A mechanical track obstacle featuring a stationary background rod with gears traveling along its length.

* **Scene**: `res://game/scenes/Obstacles/MovingGearWithRod.tscn`
* **Controller**: `MovingGearWithRodController.gd`
* **Key Properties**:
  - `move_distance`: Total length of the track rod in pixels.
  - `move_angle` & `move_direction`: Orientation angle (`0` = Right, `90` = Down, `180` = Left, `-90` = Up, or Custom).
  - `rod_breadth`: Thickness of the metal track rod (in pixels).
  - `move_speed`: Movement speed of the gears along the rod.
  - `rotation_speed`: Spinning speed of the gears.
  - `loop_reset`: `true` = gears travel from start to end and seamlessly wrap back to origin; `false` = smooth ping-pong oscillation.
  - `gear_count`: Number of gears riding the rod (1 to 20).
  - `gear_spacing`: Distance between gears (0 = automatically distributed).
  - `world_theme`: Dynamically skins both the rod texture and gear texture to match the world.

---

### 4. `gear_r` (Rotating Gear)
A stationary hazard that continuously rotates in place to block pathways.

* **Scene**: `res://game/scenes/Obstacles/RotatingGear.tscn`
* **Controller**: `RotatingGearController.gd`
* **Key Properties**:
  - `rotation_speed`: Angular rotation speed in radians per second (positive for clockwise, negative for counter-clockwise).
  - `world_theme`: Auto-applied gear texture skin.

---

### 5. `gear_rod` (Static Gear Rod Barrier)
A solid metallic obstacle rod that blocks player jumps and acts as terrain or structure.

* **Scene**: `res://game/scenes/Obstacles/GearRod.tscn`
* **Controller**: `GearRodController.gd`
* **Key Properties**:
  - `length`: Length of the rod in pixels.
  - `breadth`: Width/thickness of the rod in pixels.
  - `world_theme`: Auto-applied rod texture.

---

### 6. `falling_stone`, `falling_stone_trap`, `falling_stone_spike`
A set of dynamic falling boulder hazards triggered by proximity or custom trigger tags.

* **Scenes**:
  - Non-lethal boulder: `res://game/scenes/Obstacles/FallingStone.tscn` (applies physics knockback).
  - Lethal spike boulder: `res://game/scenes/Obstacles/FallingStoneSpike.tscn` (kills player on contact).
  - Compound trap: `res://game/scenes/Obstacles/FallingStoneTrap.tscn` (contains boulder + trigger zone).
* **Key Properties**:
  - `trigger_tag`: Matching tag linking `TriggerArea` to `FallingStone` (e.g. `"trap_1"`).
  - `fall_speed`: Initial downward velocity (e.g. `600.0`).
  - `gravity`: Downward acceleration (`1200.0`).
  - `rotation_speed`: Angular spinning while falling.
  - `knockback_force`: Impulse applied to player on non-lethal hit (`600.0`).
  - `fall_distance`: Maximum fall travel before deactivating.
  - `trigger_distance_y`: Vertical trigger zone offset in compound trap.

---

### 7. `booster` (Directional Launch Booster)
Launches the player with high velocity in the direction the booster is facing.

* **Scene**: `res://game/scenes/Obstacles/Booster.tscn`
* **Controller**: `BoosterController.gd`
* **Key Properties**:
  - `force_tier`: Pre-calibrated jump impulse presets:
    * **Tier 1 - Low**: $650.0$ force
    * **Tier 2 - Medium**: $950.0$ force
    * **Tier 3 - High**: $1300.0$ force
    * **Tier 4 - Super**: $1700.0$ force
    * **Tier 5 - Mega**: $2200.0$ force
  - `custom_force`: Custom impulse override (when $> 0$, overrides tier preset).
  - `invulnerability_duration`: Duration in seconds the player remains invincible during the boost launch ($0.6\text{s}$).
* **Editor Visuals**: Directional launch arrow indicating orientation and tier magnitude.

---

### 8. `horizontal_zone_trigger` & `trigger_area`
Camera control and event trigger volumes.

* **`horizontal_zone_trigger`**: Dynamically adjusts camera horizontal drag margins and smooth pan offsets when the player enters side rooms or wide horizontal sections.
* **`trigger_area`**: Activates linked falling stones, traps, or game events matching `trigger_tag`.

---

## 4. World Themes & Asset Skinning

The project uses a unified **World Theme Registry** located at `game/scripts/registries/world_theme_registry.gd`.

### Registering a New Theme
```gdscript
"world_5": {
    "id": "world_5",
    "name": "World 5 - Crystal Cavern",
    "background": "res://game/assets/sprites/backgrounds/Bg5.png",
    "wall_texture": "res://game/assets/sprites/ENV/Wall5.png",
    "platform_texture": "res://game/assets/sprites/atlases/tiles/CrystalTiles.png",
    "gear_texture": "res://game/assets/sprites/obstacles/Gear_Crystal.png",
    "gear_rod_texture": "res://game/assets/sprites/obstacles/Rod_Crystal.png",
    "falling_stone_texture": "res://game/assets/sprites/obstacles/Stone_Crystal.png",
    "tile_size": Vector2i(16, 16),
    "default_atlas_coords": Vector2i(1, 1),
    "theme_color": Color(0.2, 0.8, 0.9, 1.0)
}
```

### Auto-Skinning Pipeline
When `WorldThemeRegistry.set_current_theme("world_2")` or `LevelLoader.load_level()` runs:
1. The background texture is mapped to the player camera anchor.
2. Obstacles implement `apply_theme(theme_id)` and automatically load the theme's corresponding gear, rod, and stone textures.
3. Terrain tile sets are compiled with slope/block physics polygons and cached in RAM.

---

## 5. Registering New Obstacles in `ObjectRegistry`

To make a new obstacle scene available in the Level Editor palette, Inspector, and LevelLoader:

1. Create the Godot scene under `game/scenes/Obstacles/MyObstacle.tscn`.
2. Attach a script inheriting `ObstacleController` or `Node2D` with `@tool`.
3. Implement `update_components()`, `apply_theme()`, and `reset()`.
4. Open `game/scripts/registries/object_registry.gd` and add:

```gdscript
"my_obstacle": {
    "id": "my_obstacle",
    "name": "Laser Hazard",
    "scene_path": "res://game/scenes/Obstacles/LaserHazard.tscn",
    "category": "Obstacles", # "Obstacles", "Platforms", "Triggers", "Walls"
    "default_properties": {
        "rotation_speed": 0.0,
        "laser_length": 400.0,
        "cycle_interval": 3.0
    },
    "default_scale": Vector2(1, 1)
}
```

The Level Editor will instantly generate the palette button and Inspector property controls automatically!

---

## 6. Level Serialization & Gameplay Execution

### File Formats
- **`.tres` (Resource)**: Human-readable / version-control friendly level data stored under `game/assets/levels/level_XXX.tres`.
- **`.tscn` (Pre-Baked Scene)**: Fully serialized Godot packed scene generated automatically on save. Provides instant mobile loading with zero deserialization overhead.
- **`.res` (Compressed Binary)**: High-speed compressed format for production mobile deployment.

### Launching Levels in Code
```gdscript
# Launch directly via LevelLauncher
LevelLauncher.launch_level("res://game/assets/levels/level_006.tres", get_tree())

# Or load via LevelManager into gameplay
LevelManager.load_level_data("res://game/assets/levels/level_006.tres")
get_tree().change_scene_to_file("res://game/scenes/gameplay/game_play.tscn")
```
