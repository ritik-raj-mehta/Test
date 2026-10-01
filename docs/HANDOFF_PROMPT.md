# Antigravity Context Handoff & Session Continuation Prompt

Use this prompt whenever switching or resuming Antigravity sessions/conversations for this project.

---

## 📋 Copy-Paste Handoff Prompt for New Session

```markdown
Hello Antigravity! I am resuming work on the Zumpa Jump Godot project.

Please inspect `docs/HANDOFF_PROMPT.md`, `docs/CHANGES_SUMMARY.md`, and `docs/LEVEL_EDITOR_GUIDE.md` to pick up context exactly where the previous session left off.

### Project State Summary:
1. Workspace Path: `e:\Test\Test`
2. Engine: Godot 4.7.2
3. Key Architecture & Recent Work:
   - Obstacles (`MovingGearController.gd` & `PathMovingGearController.gd`) have Interval Movement (`enable_interval_movement`, `interval_time`, `interval_speed`), smooth Sinusoidal Speed Wave Curves ("start move a little -> slow down -> speed up -> slow down -> loop repeat"), uniform `gear_scale`, and theme-skinned connecting rods.
   - Level Editor (`addons/zumpa_level_editor/`) uses a single-sidebar Inspector panel layout (maximizing canvas width) with quick top-bar toggles (`🛠️ Items & Tools` and `⚙️ Inspector`).
   - Inspector layout order is: Obstacles & Primary Tools (Top) -> Inspector & Apply Button (Middle) -> Tile Map Tools & Atlas Palette (Bottom).
   - Multi-Tile Selection & Persistent Stochastic Random Pattern Fill (`Random Pattern`, `100% Solid`, `Multi-Tile Mix`).
   - `Wall.tscn` and all temporary test scenes have been removed.

Please confirm you have reviewed the documentation, acknowledge the current project state, and ask me how to proceed.
```

---

## 🔍 Key Context Reference & File Maps

### Critical Documentation Files:
- [`docs/CHANGES_SUMMARY.md`](file:///e:/Test/Test/docs/CHANGES_SUMMARY.md): Full list of deleted scenes, modified controllers, editor UI updates, and created summary files.
- [`docs/LEVEL_EDITOR_GUIDE.md`](file:///e:/Test/Test/docs/LEVEL_EDITOR_GUIDE.md): Technical architecture guide for obstacles, Level Editor controls, theme skinning, and serialization.

### Core Active Source Files:
- **Obstacle Controllers**:
  - [`game/scenes/Obstacles/MovingGearController.gd`](file:///e:/Test/Test/game/scenes/Obstacles/MovingGearController.gd)
  - [`game/scenes/Obstacles/PathMovingGearController.gd`](file:///e:/Test/Test/game/scenes/Obstacles/PathMovingGearController.gd)
  - [`game/scenes/Obstacles/SpikeController.gd`](file:///e:/Test/Test/game/scenes/Obstacles/SpikeController.gd)
  - [`game/scenes/Obstacles/BoosterController.gd`](file:///e:/Test/Test/game/scenes/Obstacles/BoosterController.gd)
  - [`game/scenes/Obstacles/FallingStoneController.gd`](file:///e:/Test/Test/game/scenes/Obstacles/FallingStoneController.gd)
- **Level Editor Plugin**:
  - [`addons/zumpa_level_editor/level_editor.tscn`](file:///e:/Test/Test/addons/zumpa_level_editor/level_editor.tscn)
  - [`addons/zumpa_level_editor/level_editor.gd`](file:///e:/Test/Test/addons/zumpa_level_editor/level_editor.gd)
  - [`addons/zumpa_level_editor/level_canvas.gd`](file:///e:/Test/Test/addons/zumpa_level_editor/level_canvas.gd)
  - [`addons/zumpa_level_editor/atlas_palette_picker.gd`](file:///e:/Test/Test/addons/zumpa_level_editor/atlas_palette_picker.gd)
- **Registries**:
  - [`game/scripts/registries/world_theme_registry.gd`](file:///e:/Test/Test/game/scripts/registries/world_theme_registry.gd)
  - [`game/scripts/registries/object_registry.gd`](file:///e:/Test/Test/game/scripts/registries/object_registry.gd)

---

## ⚡ Verification Protocol
Before claiming task completion in any session, always execute:
```powershell
& "C:\Users\ritik\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit
```
Ensure code exits cleanly with status code `0`.
