class_name SocialPopup
extends AppView

@export var facebook_button: TextureButton
@export var youtube_button: TextureButton
@export var instagram_button: TextureButton 
@export var discord_button: TextureButton
@export var back_button: BaseButton
@export var background: TextureRect

@export var _window: Control

func _on_ready() -> void:
	_on_press(facebook_button, func() -> void: OS.shell_open(UIConfig.FACEBOOK_URL))
	_on_press(youtube_button, func() -> void: OS.shell_open(UIConfig.YOUTUBE_URL))
	_on_press(instagram_button, func() -> void: OS.shell_open(UIConfig.INSTAGRAM_URL))
	_on_press(discord_button, func() -> void: OS.shell_open(UIConfig.DISCORD_URL))
	_on_press(back_button, func() -> void: close())
	uses_backdrop = true
	UIAnim.pop_in(_window)