class_name NetworkPopup
extends AppView

@export var _window: Control 
@export var _try_again_button: BaseButton 

func _on_ready() -> void:
	_on_press(_try_again_button, func() -> void: _try_again())
	uses_backdrop = true
	UIAnim.pop_in(_window)

func _try_again() -> void:
	pass