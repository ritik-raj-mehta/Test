class_name LoadingScene
extends AppView

@onready var _bar: TextureProgressBar = %LoadingBar

func _on_ready() -> void:
	SettingsApplier.apply(_save.settings_data if _save else null, _audio, _haptics)
	if PrivacyConsent.is_accepted():
		_run()
	else:
		_show_privacy_popup()

func _show_privacy_popup() -> void:
	var popup := _open_popup(ScenePaths.POLICY) as PrivacyPopup
	if popup == null:
		if _logger:
			_logger.error("LoadingScene: privacy popup failed to open, continuing without it")
		_run()
		return
	popup.accepted.connect(_on_privacy_accepted, CONNECT_ONE_SHOT)

func _on_privacy_accepted() -> void:
	PrivacyConsent.accept()
	_run()


func _run() -> void:
	_bar.value = 0.0
	var level_idx := _save.get_level() if _save else 1
	var min_duration := UIConfig.LOADING_MIN_SECONDS
	
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_bar, "value", 0.9, min_duration)
	await t.finished

	if _scene == null:
		return

	# Preload Gameplay shell and pre-warm level, theme and assets
	await _scene.preload_scene(ScenePaths.GAMEPLAY)
	LevelLauncher.prewarm_level(level_idx)

	_bar.value = 1.0
	await get_tree().process_frame

	# Instantly launch gameplay with zero hitching
	LevelLauncher.start(level_idx, _scene, _save, _bus, _logger)
