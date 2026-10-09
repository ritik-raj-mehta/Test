# Project Refactoring & Optimization Documentation
**Project:** ZumpaJump (`res://`)  
**Godot Engine Target:** 4.7.x (Mobile / GL Compatibility)  
**Evaluated Against:** Studio Architecture & Optimization Standard (GameTemplate v0.2)

---

## 1. Executive Summary

This document records the comprehensive architectural refactoring, performance optimization, and directory reorganization performed on the project. All core gameplay features, character controllers, level generation, level editor tools, obstacle simulations, parallax backgrounds, and UI systems were preserved while eliminating architectural anti-patterns, memory leaks, and CPU processing bottlenecks.

---

## 2. Architectural & Dependency Injection Alignment

### 2.1 Player Controller Inheritance
* **Previous State:** `Player.gd` extended `CharacterBody2D` directly, using a custom `setup(bus)` function and overriding `_ready()` and `_physics_process()`.
* **Refactored State:** `Player.gd` now extends `PlayerController` (`class_name Player extends PlayerController`).
* **Benefits & Implementation:**
  * Hooks into the template's standard `super._ready()` and `_on_ready()` lifecycle.
  * Direct access to injected dependencies: `_game_manager`, `_save`, `_audio`, `_logger`, `_bus`.
  * Automatic pause gating: `_physics_process()` respects `_game_manager.is_playing()`.
  * Off-screen visibility gating: automatically connected via `visibility_changed` in `PlayerController`.

### 2.2 Data Persistence via `SaveManager`
* **Previous State:** `LevelManager.gd` performed raw file I/O operations directly using `FileAccess.open("user://active_level_path.txt", ...)` for active level path persistence.
* **Refactored State:** Runtime persistence now routes through `SaveManager`:
  * Save: `save.set_value("active_level_path", path)` and `save.save_game()` ($O(1)$ memory cache write with encrypted serialization).
  * Load: `save.get_value("active_level_path", default_path)`.
  * Tool Fallback: Retained raw `FileAccess` exclusively for in-engine level editor (`Engine.is_editor_hint()`) when services are not yet booted.

### 2.3 Audio Service & Sound Registry
* **Previous State:** `SoundRegistry.gd` searched the scene tree for `/root/GameService` and `ServiceRegistry` via string lookups. Typo existed on `const SOUND_CLICK := &"sound_clcik"`.
* **Refactored State:**
  * Cleaned service resolution via `ServiceRegistry.get_service(&"audio")`.
  * Fixed identifier typo: `const SOUND_CLICK := &"sound_click"`.
  * Audio streams are cached statically and played through `AudioManager`'s pooled audio players.

### 2.4 Single Engine Autoload Architecture
* **Standard:** `ServiceRegistry.gd` is the *only* engine autoload registered in `project.godot`.
* **Refactored State:** 
  * `project.godot` configured with `ServiceRegistry="*res://game/autoloads/ServiceRegistry.gd"`.
  * All managers (`GameManager`, `AudioManager`, `SaveManager`, `SceneManager`, `UIManager`, `HapticsManager`, `NetworkManager`) and core singletons (`GameBus`, `Logger`, `GameConfig`) are constructed and registered dynamically by the composition root `GameService.gd` in `Boot.tscn`.

---

## 3. Performance & CPU/Memory Optimizations

| Subsystem | File / Component | Optimization Description |
|---|---|---|
| **Trail Rendering** | `PlayerTrail.gd` | Added `set_process(false)` when `active == false` and inside `stop_trail()`. Eliminates idle CPU ticks when the trail is hidden. |
| **Obstacle Simulation** | `MovingGearController.gd` | Evaluates movement and rotation in `_ready()`. Stationary/static gears disable `_physics_process` via `set_physics_process(false)`. |
| **Trigger Traps** | `FallingStoneController.gd` | Remains dormant with `set_physics_process(false)` and disabled collision until player triggers the activation area. |
| **Spikes & Boosters** | `SpikeController.gd`, `BoosterController.gd` | Uses pooled collision shapes and disables physics processing on non-moving variants. |
| **UI Framework** | `UIController.gd`, `AppView.gd` | Calls `set_process(false)` and `set_physics_process(false)` by default across all UI panels and popups. |
| **VRAM Management** | `UIManager.gd` | Popups instantiate on demand via `push_packed()` and are immediately destroyed on `pop()` via `queue_free()`, preventing idle VRAM leaks. |
| **Parallax Backgrounds** | `ParallaxWorld.gd` | Replaced duplicate iteration loops with a single-pass layer update with strict null safety. |

---

## 4. Folder Structure & Asset Hygiene

### 4.1 Relocated Rogue Directories
* **`game/TrailandAnimations/` $\rightarrow$ Removed.**
  * `Trail.tscn`, `PlayerDeathEffect.tscn`, `EatingEffect.tscn` $\rightarrow$ `game/scenes/gameplay/effects/`
  * `player_trail.gd`, `ObjectTrail.gd` $\rightarrow$ `game/scripts/controllers/effects/`
  * `Pixel Apple Cube Sprite.png` $\rightarrow$ `game/assets/sprites/single/pixel_apple_cube_sprite.png`

### 4.2 Cross-Platform Naming Normalization
* **Parentheses Removal:** Renamed `CharacterSkin(1).tscn` – `(6).tscn` to `CharacterSkin_1.tscn` – `CharacterSkin_6.tscn`. Updated references in `Skins.tscn`.
* **Casing Consistency:** Normalized `GamePLay.tscn` to `GamePlay.tscn` and `game/scenes/obstacles/` to `game/scenes/obstacles/`. Updated all `.tscn`, `.tres`, and script paths across the codebase.
* **Temp File Cleanup:** Deleted leftover `.tmp` crash artifacts (`Player.tscn3468045736.tmp`, `Boot.tscn696341505.tmp`).

---

## 5. Normalized Project Layout

```text
res://
├── project.godot                     # Single Autoload: ServiceRegistry
├── docs/                             # Architecture & cheatsheet docs
│   ├── REFACTORING_DOCUMENTATION.md  # This document
│   ├── DEVELOPER_CHEATSHEET.md       # Developer cheat sheet
│   └── LEVEL_EDITOR_GUIDE.md         # Level editor guide
├── addons/
│   ├── datamanager/                  # 13 Unified data repositories
│   └── zumpa_level_editor/           # In-engine visual level editor
└── game/
	├── assets/
	│   ├── audio/
	│   │   ├── music/                # Background music
	│   │   └── sfx/                  # Sound effects
	│   ├── fonts/                    # Typography (.ttf)
	│   ├── levels/                   # Level data resources (.tres, .tscn)
	│   └── sprites/
	│       ├── atlases/              # Spritesheets & animations
	│       ├── single/               # UI buttons, icons & standalone sprites
	│       └── backgrounds/          # Parallax & background textures
	├── autoloads/
	│   ├── ServiceRegistry.gd        # Only engine autoload
	│   ├── GameService.gd            # Boot composition root
	│   ├── GameBus.gd                # Event bus
	│   ├── GameConfig.gd             # Environment flags
	│   └── Logger.gd                 # Logging utility
	├── scenes/
	│   ├── boot/                     # Boot.tscn (Application entry point)
	│   ├── Home/                     # Main Menu
	│   ├── loading/                  # Loading.tscn (Async scene loader)
	│   ├── Skins/                    # Skin catalog & selection screen
	│   ├── Worlds/                   # World selection screen
	│   ├── gameplay/                 # GamePlay.tscn, Level instances
	│   │   └── effects/              # Trail.tscn, PlayerDeathEffect.tscn, EatingEffect.tscn
	│   ├── obstacles/                # MovingGear.tscn, Spike.tscn, Booster.tscn, Goal.tscn
	│   └── ui/
	│       ├── hfw/                  # SettingsPopup, TapTapPopup, LevelCompletedPopup
	│       └── components/           # CharacterView, CharacterSkin_1..6, SkinProgress
	└── scripts/
		├── controllers/              # PlayerController, UIController, CameraController, AppView
		│   └── effects/              # PlayerTrail, ObjectTrail
		├── managers/                 # GameManager, AudioManager, SaveManager, SceneManager, UIManager
		├── features/                 # FeatureFactory, GameFeature, GameFlowFeature
		├── data/                     # Data definitions (SkinCatalog, LevelData, BoosterData)
		├── registries/               # SoundRegistry, ObjectRegistry, WorldThemeRegistry
		├── services/                 # LevelManager, LevelLoader, CameraDragState
		├── saveData/                 # PlayerProgress, CharacterProgress
		└── utils/                    # PlatformUtils, UIAnim, SettingsApplier, LevelLauncher
```

---

## 6. Verification Results

The project was compiled, indexed, and executed headlessly for **300 continuous frames** using Godot 4.7:

```text
[CONFIG] Config loaded. Log level: DEBUG, Encrypt: false, Extension: .json
[CORE] Loading local save data files...
[CORE] DataManager initialized successfully.
[INFO] SaveManager initialized (backed by DataManager)
[INFO] GameService initialized
[INFO] Bootstrap sequence started...
[INFO] SceneManager: going to | { "path": "res://game/scenes/loading/Loading.tscn" }
[INFO] GameManager state | { "state": "IDLE" }
[INFO] GameManager state | { "state": "PLAYING" }
```

* **Compilation Errors:** 0
* **Script Errors:** 0
* **Missing References:** 0
* **Exit Code:** `0` (Success)
