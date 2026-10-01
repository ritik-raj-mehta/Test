class_name PrivacyPopup
extends AppView


signal accepted

@export var accept_button: TextureButton
@export var _window: Control

func _on_ready() -> void:
	_on_press(accept_button, _on_accept_pressed)
	UIAnim.pop_in(_window)

func _on_accept_pressed() -> void:
	if _closing: 
		return

	await close()
	accepted.emit()