# Automated Regression Tests & Verification Tools

This folder contains repeatable automated test scripts designed to run headless with Godot Engine to guarantee regression protection.

## Test Scripts

### 1. Level Integrity Check (`check_levels.gd`)
Indexes and validates all 51 authored `.tres` levels, counts interactive objects, verifies world themes, checks object IDs against `ObjectRegistry`, and ensures every referenced `.tscn` scene resource exists on disk.

**Execution Command:**
```bash
godot --headless -s "res://tests/check_levels.gd"
```
**Expected Result:**
- Discovers 51 levels
- Total Valid Levels Loaded: 51 / 51
- Failed Levels: 0
- Missing Object IDs: 0
- Missing Scene Paths: 0
- Exit Code: `0`

---

### 2. Runtime Boot & Services Simulation (`test_runtime.gd`)
Bootstraps the game from `Boot.tscn`, checks the `ServiceRegistry` autoload for all 12 registered services across 240 frames, verifies DataManager initialization, and tests scene transition into gameplay without requiring a display or window manager.

**Execution Command:**
```bash
godot --headless -s "res://tests/test_runtime.gd"
```
**Expected Result:**
- Loads `Boot.tscn`
- Confirms `ServiceRegistry` contains `game`, `audio`, `save`, `scene`, `ui`, `bus`, `logger`, `config`
- Ticks 240 frames cleanly
- Exit Code: `0`

---

### 3. Engine Project Scan
Performs a full engine syntax, parse, and class-cache validation.

**Execution Command:**
```bash
godot --headless --editor --quit
```
**Expected Result:**
- Exit Code: `0` (0 script errors, 0 warnings)
