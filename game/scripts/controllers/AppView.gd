class_name AppView
extends UIController

## AppView — base class for every screen (SceneManager) and popup (UIManager).
## The UI itself lives in the .tscn (drag textures there). Scripts only hold behaviour:
## they look nodes up with unique names (%Name) and wire them to game/save logic.
##
## Extends UIController, so UIManager / SceneManager inject it automatically.
## Adds the extra services UI screens need (save, scene, haptics, logger, bus)
## and a few small helpers. Override _on_ready(), never _ready().
##
## Testable without a registry: call inject_dependencies(...) + inject_extras(...).

var _save:    SaveManager
var _scene:   SceneManager
var _haptics: HapticsManager
var _logger:  Node
var _bus:     Node
var _game:    GameManager
var _closing: bool = false
var uses_backdrop: bool = false

## Registry adapter (called by SceneManager for scenes and UIManager for popups).
func inject_services(registry: Node) -> void:
	if not registry:
		return
	inject_extras(
		registry.get_service(&"save") as SaveManager,
		registry.get_service(&"scene") as SceneManager,
		registry.get_service(&"haptics") as HapticsManager,
		registry.get_service(&"logger") as Node,
		registry.get_service(&"bus") as Node,
		registry.get_service(&"game") as GameManager,
		registry.get_service(&"audio") as AudioManager
	)
	super.inject_services(registry)  # ui/audio/game → triggers _on_ready()

func inject_extras(save: SaveManager, scene: SceneManager, haptics: HapticsManager, logger: Node, bus: Node, game: GameManager, audio: AudioManager) -> void:
	_save = save
	_scene = scene
	_haptics = haptics
	_logger = logger
	_bus = bus
	_game = game
	_audio = audio

# ── Helpers for subclasses ────────────────────────────────────────────────

## Wires a button: haptic + click sound, then your callback.
func _on_press(button: BaseButton, callback: Callable) -> void:
	button.pressed.connect(func() -> void:
		_click()
		callback.call()
	)

## Makes any Control (e.g. a full-screen "TapArea") react to mouse click / touch.
func _bind_tap(area: Control, callback: Callable) -> void:
	area.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			callback.call()
		elif e is InputEventScreenTouch and e.pressed:
			callback.call()
	)

func _click() -> void:
	if _haptics:
		_haptics.light()
	if _audio and ResourceLoader.exists(UIConfig.CLICK_SFX_PATH):
		_audio.play_sfx(load(UIConfig.CLICK_SFX_PATH) as AudioStream)

func _go(scene_path: String) -> void:
	if _scene:
		_scene.go_to(scene_path)

## Pushes a popup through UIManager and returns the instance (or null).
func _open_popup(path: String) -> Control:

	print("OPEN POPUP PATH: ", path)

	if _ui_manager == null:
		push_error("AppView: UIManager is NULL.")
		return null

	if path.is_empty():
		push_error("AppView: Popup path is EMPTY.")
		return null

	if not ResourceLoader.exists(path):
		push_error(
			"AppView: Popup scene does not exist: " + path
		)
		return null

	var packed := load(path) as PackedScene

	if packed == null:
		push_error(
			"AppView: Failed to load popup: " + path
		)
		return null

	_ui_manager.push_packed(packed)

	var current := _ui_manager.current()

	print("CURRENT POPUP: ", current)

	if current:
		print("CURRENT CLASS: ", current.get_class())
		print("CURRENT SCRIPT: ", current.get_script())

	return current

func close() -> void:
	if _closing:
		return
	_closing = true
	await UIAnim.pop_out(self)
	if is_inside_tree() and _ui_manager:
		_ui_manager.pop_screen(self)
		_game.resume()  

# ── Sound / music switches (shared by SettingsPopup and the pause menu) ───

func _is_sfx_on() -> bool:
	return _save == null or _save.settings_data == null or _save.settings_data.sfx_enabled

func _is_music_on() -> bool:
	return _save == null or _save.settings_data == null or _save.settings_data.music_enabled

func _set_sfx(on: bool) -> void:
	_update_settings(func(d: GameModels.SettingsData) -> void: d.sfx_enabled = on)

func _set_music(on: bool) -> void:
	_update_settings(func(d: GameModels.SettingsData) -> void: d.music_enabled = on)

func _update_settings(mutator: Callable) -> void:
	if _save == null:
		return
	_save.settings.mutate(mutator)
	SettingsApplier.apply(_save.settings_data, _audio, _haptics)
	_save.save_game()
