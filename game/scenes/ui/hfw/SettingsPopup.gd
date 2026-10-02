class_name SettingsPopup
extends AppView

## SettingsPopup — sound / music toggles, Terms, Credits, Privacy, Back.
## Layout: SettingsPopup.tscn. Values persist through SaveManager.settings and
## are applied live via SettingsApplier.
##
## Each toggle button needs two child TextureRects named "IconOn" / "IconOff".

@export var _window: Control #= %Window
@export var _sfx_toggle: BaseButton #= %SfxToggle
@export var _music_toggle: BaseButton #= %MusicToggle
@export var _terms_button: BaseButton #= %TermsButton
@export var _credits_button: BaseButton #= %CreditsButton
@export var _privacy_button: BaseButton #= %PrivacyButton
@export var _back_button: BaseButton #= %BackButton
@export var background: TextureRect 
@export var _blur_bg_list: Array[Texture] 

func _on_ready() -> void:
	var s: GameModels.SettingsData = _save.settings_data if _save else null
	_setup_toggle(_sfx_toggle, s.sfx_enabled if s else true, _on_sfx_toggled)
	_setup_toggle(_music_toggle, s.music_enabled if s else true, _on_music_toggled)
	_on_press(_terms_button, func() -> void: OS.shell_open(UIConfig.TERMS_URL))
	_on_press(_credits_button, func() -> void: _open_popup(ScenePaths.CREDITS))
	_on_press(_privacy_button, func() -> void: OS.shell_open(UIConfig.PRIVACY_URL))
	_on_press(_back_button, close)
	UIAnim.pop_in(_window)
	_Setup_Bg_at_first_world()

func _Setup_Bg_at_first_world() -> void:
	var world_index = 0
	var current_level = _save.get_level() 
	if current_level <= 10:
		world_index = 0
	elif current_level <= 20:
		world_index = 1
	elif current_level <= 30:
		world_index = 2	
	elif current_level <= 40:
		world_index = 3
	elif current_level <= 50:
		world_index = 4
	else:
		world_index = 0

	select_bg_for_world(world_index)

func select_bg_for_world(index: int) -> void:
	if index < _blur_bg_list.size():
		background.texture = _blur_bg_list[index]
	else:
		background.texture = null
		_logger.warn("WorldsScene: no blur background for world index ", index)

func _setup_toggle(button: BaseButton, enabled: bool, handler: Callable) -> void:
	button.button_pressed = enabled   # set before connecting → nothing is saved on open
	_show_toggle_state(button, enabled)
	button.toggled.connect(func(on: bool) -> void:
		_show_toggle_state(button, on)
		handler.call(on)
	)

func _show_toggle_state(button: Node, on: bool) -> void:
	(button.get_node("IconOn") as CanvasItem).visible = on
	(button.get_node("IconOff") as CanvasItem).visible = not on

func _on_sfx_toggled(on: bool) -> void:
	_update_settings(func(d: GameModels.SettingsData) -> void: d.sfx_enabled = on)
	if on:
		_click()

func _on_music_toggled(on: bool) -> void:
	_update_settings(func(d: GameModels.SettingsData) -> void: d.music_enabled = on)
	if on:
		_click()

func _update_settings(mutator: Callable) -> void:
	if _save == null:
		return
	_save.settings.mutate(mutator)
	SettingsApplier.apply(_save.settings_data, _audio, _haptics)
	_save.save_game()
