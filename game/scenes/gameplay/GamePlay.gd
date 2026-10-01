class_name GamePlay
extends AppView


const GOAL_FALLBACK_Y: float = -500.0
const HOME_OUT_DELAY_SCALE: float = 0.5 

@export var _level_root: Node2D 
@export var _background: TextureRect
@export var _home_layer: CanvasLayer
@export var _level_pill: Control
@export var _level_label: Label
@export var _tap_label: Control
@export var _tap_area: Control
@export var _settings_button: BaseButton
@export var _levels_button: BaseButton
@export var _skins_button: BaseButton

var _overlay: Control      
var _started: bool = false  
var _home_tweens: Array[Tween] = []


# ── Setup ─────────────────────────────────────────────────────────────────

func _on_ready() -> void:
	if _bus == null or _game_manager == null:
		push_error("GamePlay: bus / game manager not injected.")
		return
	_bind_home_ui()
	if not _bus.tap_tap_started.is_connected(
		_open_tap_tap
	):
		_bus.tap_tap_started.connect(
			_open_tap_tap
		)

	if not _bus.tap_tap_completed.is_connected(
		_on_tap_tap_completed
	):
		_bus.tap_tap_completed.connect(
			_on_tap_tap_completed
		)
	_start_level(LevelManager.get_default_level())

func _open_tap_tap() -> void:
	_open_popup(ScenePaths.TAP_TAP)

func _on_tap_tap_completed(
	progress_before: float,
	progress_after: float
) -> void:

	print("GamePlay: TapTap completed.")
	print("Before: ", progress_before)
	print("After: ", progress_after)

	var tap_popup := _ui_manager.current() as TapTapPopup

	if tap_popup:
		await tap_popup.close()

	# Give UIManager one frame to finish removing the popup.
	await get_tree().process_frame

	var level_popup := _open_popup(
		ScenePaths.LEVEL_COMPLETED
	) as LevelCompletedPopup

	if level_popup == null:
		push_error(
			"GamePlay: Failed to open LevelCompletedPopup."
		)
		return

	level_popup.show_result(
		0,
		progress_before,
		progress_after
	)

func _bind_home_ui() -> void:
	_bind_tap(_tap_area, _on_tap_to_play)
	_on_press(_settings_button, func() -> void: _open_overlay(ScenePaths.SETTINGS))
	_on_press(_levels_button, func() -> void: _open_overlay(ScenePaths.WORLDS))
	_on_press(_skins_button, func() -> void: _open_overlay(ScenePaths.SKINS))
	UIAnim.pulse(_tap_label)


# ── Level ─────────────────────────────────────────────────────────────────

func _start_level(data: LevelData) -> void:
	if data == null:
		push_error("GamePlay: Failed to obtain LevelData")
		return
	var level := _spawn_level(data)
	var player := _setup_game(level, data)
	if player == null:
		return
	_apply_world_theme(data, player)
	_refresh_level_info(data)
	_enter_tap_to_play()


func _spawn_level(data: LevelData) -> Node:
	for child in _level_root.get_children():
		child.queue_free()

	var level: Node = null
	var path := _resolve_level_scene_path(data)
	if _resource_exists(path):
		var packed := load(path) as PackedScene
		if packed:
			level = packed.instantiate()

	if level:
		_level_root.add_child(level)
	else:
		level = Node2D.new()
		level.name = "LevelRootInstance"
		_level_root.add_child(level)
		LevelLoader.load_level(data, level)
	return level


func _resolve_level_scene_path(data: LevelData) -> String:
	var path := LevelManager.get_active_level_path().get_basename() + ".tscn"
	if _resource_exists(path):
		return path
	path = "res://game/assets/levels/" + data.level_id + ".tscn"
	if not _resource_exists(path):
		LevelManager.bake_level_to_tscn(data, path)
	return path


func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _setup_game(level: Node, data: LevelData) -> Player:
	var actors := _find_actors(level)
	var player: Player = actors["player"] if actors["player"] else _spawn_player(level, data)
	var goal: Goal = actors["goal"] if actors["goal"] else _spawn_goal(level, data)
	var camera: CameraController = actors["camera"]
	if camera == null and player != null:
		camera = player.get_node_or_null("Camera2D") as CameraController

	if player == null or goal == null or camera == null:
		push_error("GamePlay: level has no Player, Goal, or Camera.")
		return null

	var game := Game.new()
	game.name = "Game"
	level.add_child(game)
	game.initialize_game(_bus, data, player, goal, camera)
	return player


func _find_actors(level: Node) -> Dictionary:
	var player: Player = null
	var goal: Goal = null
	var camera: CameraController = null
	for n in level.find_children("*", "", true, false):
		if player == null and (n is Player or n.name == "CharacterBody2D" or n.name == "Player"):
			player = n as Player
		elif goal == null and (n is Goal or n.name == "Goal" or n.name.begins_with("Goal") \
				or n.name.begins_with("WinArea") or n.name.begins_with("win_area")):
			goal = n as Goal
		elif camera == null and n is CameraController:
			camera = n as CameraController
	return { "player": player, "goal": goal, "camera": camera }


func _spawn_player(level: Node, data: LevelData) -> Player:
	var prefab: PackedScene = LevelLoader.get_player_prefab()
	if prefab == null:
		return null
	var player := prefab.instantiate() as Player
	if player:
		player.position = data.player_start
		level.add_child(player)
	return player


func _spawn_goal(level: Node, data: LevelData) -> Goal:
	if not ResourceLoader.exists(ScenePaths.GOAL_SCENE_PATH):
		return null
	var packed := load(ScenePaths.GOAL_SCENE_PATH) as PackedScene
	var goal: Goal = packed.instantiate() as Goal if packed else null
	if goal:
		goal.position = Vector2(data.level_size.x / 2.0, GOAL_FALLBACK_Y)
		level.add_child(goal)
	return goal


func _apply_world_theme(data: LevelData, player: Player) -> void:
	WorldThemeRegistry.set_current_theme(data.world_theme)
	var bg_tex = WorldThemeRegistry.get_background_texture(data.world_theme)

	if bg_tex:
		if _background:
			_background.texture = bg_tex
		if player.has_method("set_background_texture"):
			player.call("set_background_texture", bg_tex)

	# Gears, falling stones, goal fruits, etc. pick up the theme.
	for node in _level_root.find_children("*", "", true, false):
		if "world_theme" in node:
			node.set("world_theme", data.world_theme)
		if node.has_method("apply_theme"):
			node.call("apply_theme", data.world_theme)


func _refresh_level_info(data: LevelData) -> void:
	_level_label.text = "Level %d" % _selected_level()


func _selected_level() -> int:
	if _save == null:
		return 1
	return int(_save.get_value(UIConfig.SELECTED_LEVEL_KEY, _save.get_level()))


# ── Tap to Play / pause ───────────────────────────────────────────────────

func _enter_tap_to_play() -> void:
	_started = false
	_game_manager.reset()
	_game_manager.start()
	_game_manager.pause()
	_show_home_ui()


func _on_tap_to_play() -> void:
	if _started or is_instance_valid(_overlay):
		return
	_started = true
	_click()
	_game_manager.resume()
	_hide_home_ui()

func _home_slides() -> Array:
	return [
		[_level_pill, UIAnim.Edge.TOP, 0.0],
		[_levels_button, UIAnim.Edge.LEFT, 0.08],
		[_settings_button, UIAnim.Edge.RIGHT, 0.08],
		[_skins_button, UIAnim.Edge.LEFT, 0.16],
	]

func _show_home_ui() -> void:
	_kill_home_tweens()
	_home_layer.show()
	_tap_area.show()
	for slide in _home_slides():
		_home_tweens.append(UIAnim.slide_in(slide[0], slide[1], slide[2]))
	_tap_label.modulate.a = 0.0
	_fade_tap_label(1.0, 0.3)

func _hide_home_ui() -> void:
	_kill_home_tweens()
	_tap_area.hide()
	_fade_tap_label(0.0)
	var last: Tween = null
	for slide in _home_slides():
		last = UIAnim.slide_out(slide[0], slide[1], slide[2] * HOME_OUT_DELAY_SCALE)
		_home_tweens.append(last)
	await last.finished
	if _started:
		_home_layer.hide()


func _fade_tap_label(alpha: float, delay: float = 0.0) -> void:
	var t := _tap_label.create_tween()
	t.tween_property(_tap_label, "modulate:a", alpha, 0.25).set_delay(delay)
	_home_tweens.append(t)


func _kill_home_tweens() -> void:
	for t in _home_tweens:
		if t and t.is_valid():
			t.kill()
	_home_tweens.clear()

func _open_overlay(path: String) -> void:
	if _started or is_instance_valid(_overlay):
		return  # buttons are only usable while waiting for the tap
	_game_manager.pause()
	_overlay = _open_popup(path)
	if _overlay == null:
		_resume_if_started()
		return
	_overlay.tree_exited.connect(_on_overlay_closed, CONNECT_ONE_SHOT)


func _on_overlay_closed() -> void:
	_overlay = null
	if _scene and _scene.is_loading():
		return  
	_resume_if_started()


func _resume_if_started() -> void:
	if _started:
		_game_manager.resume()


# ── Dev HUD ───────────────────────────────────────────────────────────────

func _on_dev_level_picked(path: String) -> void:
	_start_level(LevelManager.load_level_data(path))


func _open_editor() -> void:
	_game_manager.resume()  # never leave the tree paused when leaving
	get_tree().change_scene_to_file(ScenePaths.LEVEL_EDITOR)
