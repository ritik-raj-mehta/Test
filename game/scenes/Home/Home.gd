class_name HomeScene
extends AppView


@export var _level_label: Label #= %LevelLabel
@export var _tap_label: Control #= %TapLabel
@export var _tap_area: Control #= %TapArea
@export var _settings_button: BaseButton #= %SettingsButton
@export var _levels_button: BaseButton #= %LevelsButton
@export var _skins_button: BaseButton #= %SkinsButton

func _on_ready() -> void:
	_bind_tap(_tap_area, _on_play)
	_on_press(_settings_button, _on_settings)
	_on_press(_levels_button, func() -> void: _go(ScenePaths.WORLDS))
	_on_press(_skins_button, func() -> void: _go(ScenePaths.SKINS))
	_level_label.text = "Level %d" % (_save.get_level() if _save else 1)
	UIAnim.pulse(_tap_label)
	if _logger:
		_logger.info("HomeScene loaded successfully.")

func _on_play() -> void:
	_click()
	LevelLauncher.start(_save.get_level() if _save else 1, _scene, _save, _bus, _logger)

func _on_settings() -> void:
	_open_popup(ScenePaths.SETTINGS)
