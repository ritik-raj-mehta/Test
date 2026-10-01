# Developer Cheatsheet

This is the beginner guide for the current template. Follow the rules in this file before copying patterns from older documents.

## 1. How the project starts

When you press **Play**:

```text
project.godot
  -> ServiceRegistry autoload
  -> Boot.tscn
  -> GameService creates and configures shared services
  -> Home.tscn is loaded
```

`ServiceRegistry` is the only project autoload. `GameService` is a node inside `Boot.tscn`, not a separate project autoload. Do not add a new autoload for every manager.

## 2. Which service should I use?

| Service | Use it for | Important methods |
|---|---|---|
| `GameManager` | Game state | `start()`, `pause()`, `resume()`, `game_over()` |
| `AudioManager` | Music and sound effects | `play_music()`, `play_sfx()`, `mute()` |
| `HapticsManager` | Mobile vibration | `light()`, `medium()`, `heavy()` |
| `SaveManager` | Local player data | `add_coins()`, `complete_level()`, `save_game()` |
| `SceneManager` | Full scene changes | `go_to()`, `preload_scene()` |
| `UIManager` | Popup/panel stack | `push_packed()`, `pop()` |
| `GameBus` | Events/signals | `game_started`, `game_over`, `coins_changed` |
| `Logger` | Logs | `debug()`, `info()`, `warn()`, `error()` |
| `NetworkManager` | Cloud Function calls | `check_version()`, `get_profile()`, `sync_progress()` |

## 3. The easiest way to work with services

For a scene-placed `PlayerController` or `UIController`, do not look up services yourself. `SceneManager` injects the required services automatically when it loads the scene.

Use `_on_ready()`, not `_ready()`, in subclasses:

```gdscript Player.gd
extends PlayerController

func _on_ready() -> void:
	# Dependencies are ready here.
	# Use _game_manager, _audio, _save, _logger and _bus here.
	pass
```

The fields beginning with `_` are protected by convention. A child class can use them, but ordinary unrelated scripts should receive their own dependencies explicitly.

## 4. Getting a service from the registry

Use the registry only at a composition boundary—for example, level setup, bootstrap code, or a small prototype scene. Do not use it everywhere in gameplay code.

```gdscript Level.gd
extends Node2D

func _ready() -> void:
	var game := ServiceRegistry.get_service(&"game") as GameManager
	var audio := ServiceRegistry.get_service(&"audio") as AudioManager

	if game == null or audio == null:
		push_error("Required game services are not available")
		return

	game.start()
```

Available keys are `&"game"`, `&"audio"`, `&"haptics"`, `&"save"`, `&"scene"`, `&"ui"`, `&"network"`, `&"bus"`, `&"logger"` and `&"config"`.

## 5. Audio

```gdscript AudioExample.gd
var audio: AudioManager

func play_jump_sound(jump_sound: AudioStream) -> void:
	if audio:
		audio.play_sfx(jump_sound)

func play_background_music(music: AudioStream) -> void:
	if audio:
		audio.play_music(music)
```

Assign `audio` through dependency injection. Do not create another `AudioManager` in every scene.

## 6. Save data

Use the injected `SaveManager`. Important changes should be saved explicitly.

```gdscript SaveExample.gd
var save: SaveManager

func reward_player() -> void:
	if save == null:
		return

	save.add_coins(100)
	save.save_game()

func finish_level(level_number: int) -> void:
	if save == null:
		return

	save.complete_level(level_number, 3, 150)
	save.save_game()
```

For custom values:

```gdscript SaveExample.gd
save.set_value("selected_mode", "classic")
save.save_game()

var mode: String = str(save.get_value("selected_mode", "classic"))
```

For direct model changes, use `mutate()` or call `mark_dirty()` yourself:

```gdscript SaveExample.gd
save.economy.mutate(func(data: GameModels.EconomyData) -> void:
	data.currencies["coins"] = int(data.currencies.get("coins", 0)) + 100
)
save.save_game()
```

Local data is stored under `user://saves/`. Debug builds use JSON by default; release builds use the DataManager's encrypted `.dat` configuration. Cloud sync is not ready to assume working in this template.

## 7. Starting, pausing and ending the game

```gdscript GameFlow.gd
var game: GameManager

func start_game() -> void:
    if game:
        game.start()

func pause_game() -> void:
    if game:
        game.pause()

func resume_game() -> void:
    if game:
        game.resume()

func end_game() -> void:
    if game:
        game.game_over("Player lost")
```

`GameManager` changes the game state and emits events through `GameBus`. It does not automatically create gameplay, UI or levels.

## 8. Changing scenes

Use `SceneManager` for complete scene changes:

```gdscript SceneExample.gd
var scene_manager: SceneManager

func open_level() -> void:
    if scene_manager:
        scene_manager.go_to("res://game/scenes/gameplay/Level_01.tscn")
```

The path must point to an existing `.tscn` file. `preload_scene()` is optional and is useful for warming up a large scene before calling `go_to()`.

## 9. Opening and closing UI panels

`UIManager` owns small panels and keeps them in a stack. The argument to `push_packed()` must be a `PackedScene` resource.

```gdscript MenuExample.gd
@export var settings_panel: PackedScene
var ui_manager: UIManager

func open_settings() -> void:
    if ui_manager and settings_panel:
        ui_manager.push_packed(settings_panel)

func close_current_panel() -> void:
    if ui_manager:
        ui_manager.pop()
```

For a panel that extends `UIController`, override `_on_ready()`. Call `close()` from the panel to pop itself.

## 10. GameBus events

Use the bus when one system needs to announce something without knowing who is listening. Connect signals when the listener enters the scene and disconnect them if you manually connect from a long-lived object.

```gdscript ScoreLabel.gd
var bus: Node

func connect_to_bus() -> void:
    if bus:
        bus.coins_changed.connect(_on_coins_changed)

func _on_coins_changed(new_amount: int) -> void:
    print("Coins: ", new_amount)
```

Emit an event only when you own the event source:

```gdscript CoinSystem.gd
var bus: Node

func coins_changed(amount: int) -> void:
    if bus:
        bus.coins_changed.emit(amount)
```

Do not invent a new signal when an existing signal already represents the event.

## 11. FeatureFactory: when to use it

You do **not** need FeatureFactory for every node. Use it when creating a feature or controller at runtime and giving it dependencies before adding it to the scene tree.

If a node is already placed in a `.tscn` scene, let the normal scene injection flow handle it. Any node or scene root placed in a `.tscn` file can implement `inject_services(registry: Node)` which delegates to `inject_dependencies(...)`. When `SceneManager` loads a scene, it automatically calls `inject_services(_registry)` on the scene root and all descendant nodes implementing it.

For a runtime-created `GameFeature`:

```gdscript Level.gd
var flow := FeatureFactory.create_feature(
    GameFlowFeature,
    self,
    {"game": game_manager}
) as GameFlowFeature

flow.start_game()
```

For a runtime-created controller:

```gdscript Level.gd
var player := FeatureFactory.create_node(
    PlayerController,
    self,
    func(node: PlayerController) -> void:
        node.inject_dependencies(game_manager, audio, save, logger, bus)
) as PlayerController
```

FeatureFactory does not find services, start features, or clean them up. You provide dependencies and call `start()` or `queue_free()` when appropriate.

## 12. Referencing nodes safely

Use these options in this order:

1. **Child in the same scene:** mark the node as a scene-unique name and use `%NodeName`.
2. **Designer-assigned reference:** use an exported variable and drag the node in the Inspector.
3. **Runtime-created relationship:** pass the reference through a method such as `camera.follow(player)`.
4. **Dynamic discovery:** use Godot groups for objects that can appear or disappear.

```gdscript CameraSetup.gd
@export var player: Node2D

func _ready() -> void:
    if player:
        follow(player)
```

Avoid `get_node("/root/Main/Level1/Player")` and chains such as `get_parent().get_parent()`. They break when the scene hierarchy changes.

## 13. Adding a new gameplay script

1. Decide whether it is a scene, controller, manager or feature.
2. Put it in the matching folder under `game/`.
3. Give it only the dependencies it actually needs.
4. For a scene-placed controller:
   - Provide an explicit `inject_dependencies(...)` method (keeps it testable without any registry).
   - Implement `inject_services(registry: Node)` as an adapter that forwards registry services into `inject_dependencies(...)`.
   - Extend `PlayerController` or `UIController` when appropriate and implement `_on_ready()`.
5. For a runtime-created feature, use `FeatureFactory`.
6. Save important player changes through `SaveManager`.
7. Add logs with the injected `Logger` while developing.

## 14. Things not to do

- Do not add a new project autoload for a normal manager.
- Do not access services using hardcoded `/root/...` paths.
- Do not write saves with raw `FileAccess`; use `SaveManager`.
- Do not modify a repository model directly without `mutate()` or `mark_dirty()`.
- Do not override `_ready()` in a dependency-based controller unless you know the injection timing.
- Do not create a second `GameService`, `GameManager`, `SaveManager` or `AudioManager` inside a gameplay scene.
- Do not enable the DataManager editor plugin while `GameService` is creating DataManager nodes.
- Do not assume Firebase, analytics, ads or cloud sync are production-ready.

## 15. Folder map

| Folder | Put this there |
|---|---|
| `game/scenes/boot/` | Startup scene and bootstrap script |
| `game/scenes/Home/` | Home/menu scene |
| `game/scenes/gameplay/` | Levels and core gameplay scenes |
| `game/scenes/loading/` | Loading screens |
| `game/scenes/ui/mfw/` | Placeholder panels |
| `game/scenes/ui/hfw/` | Polished panels |
| `game/scripts/controllers/` | Reusable scene controllers |
| `game/scripts/features/` | Reusable runtime features and factories |
| `game/scripts/managers/` | Shared application services |
| `game/autoloads/` | Composition and support scripts |
| `game/assets/` | Audio, fonts, sprites and backgrounds |
| `addons/datamanager/` | Persistence implementation |
| `addons/firebaseServer/` | TypeScript backend scaffold |

## Final rule

If you are unsure, keep the code simple: place the node in a scene, use the existing base controller, receive dependencies explicitly, and save through `SaveManager`. Only introduce a manager, feature or autoload when the existing project structure cannot solve the problem.
