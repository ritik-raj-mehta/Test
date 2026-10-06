class_name QuitPopup
extends AppView

@export var yes_button: TextureButton
@export var no_button: TextureButton
@export var background: TextureRect

@export var _window: Control

func _on_ready() -> void:
	_on_press(yes_button, func() -> void: get_tree().quit())
	_on_press(no_button, func() -> void: close())
	uses_backdrop = true
	UIAnim.pop_in(_window)