class_name UIShowcase
extends AppView

## UIShowcase — dev-only launcher for every screen/popup (no gameplay needed).
## Run this scene directly (F6): it boots GameService itself if nothing has yet.
## Layout: UIShowcase.tscn

@onready var _loading: BaseButton = %LoadingButton
@onready var _home: BaseButton = %HomeButton
@onready var _skins: BaseButton = %SkinsButton
@onready var _worlds: BaseButton = %WorldsButton
@onready var _settings: BaseButton = %SettingsButton
@onready var _credits: BaseButton = %CreditsButton
@onready var _tap_tap: BaseButton = %TapTapButton
@onready var _level_completed: BaseButton = %LevelCompletedButton

func _ready() -> void:
	var registry := get_tree().root.get_node_or_null("ServiceRegistry")
	if registry and not registry.has_service(&"ui"):
		var service: Node = load("res://game/autoloads/GameService.gd").new()
		service.name = "GameService"
		get_tree().root.add_child.call_deferred(service)
		await get_tree().process_frame
		await get_tree().process_frame
	super._ready()
	if registry:
		inject_services(registry)  # direct-run scenes are not injected by SceneManager

func _on_ready() -> void:
	_on_press(_loading, func() -> void: _go(ScenePaths.LOADING))
	_on_press(_home, func() -> void: _go(ScenePaths.GAMEPLAY))
	_on_press(_skins, func() -> void: _go(ScenePaths.SKINS))
	_on_press(_worlds, func() -> void: _go(ScenePaths.WORLDS))
	_on_press(_settings, func() -> void: _open_popup(ScenePaths.SETTINGS))
	_on_press(_credits, func() -> void: _open_popup(ScenePaths.CREDITS))
	_on_press(_tap_tap, func() -> void: _open_popup(ScenePaths.TAP_TAP))
	_on_press(_level_completed, _open_level_completed)

func _open_level_completed() -> void:
	var p := _open_popup(ScenePaths.LEVEL_COMPLETED) as LevelCompletedPopup
	if p:
		p.show_result(12, 0.4, 0.7)
