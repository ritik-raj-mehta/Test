class_name CreditsPopup
extends AppView

## CreditsPopup — fills %CreditsList from UIConfig.CREDITS using CreditEntry.tscn.
## Layout: CreditsPopup.tscn (assign `entry_scene` in the inspector).

# @export var entry_scene: PackedScene

@export var _content: Control #= %Margin
# @export var _list: VBoxContainer #= %CreditsList
@export var _back_button: BaseButton #= %BackButton

func _on_ready() -> void:
	uses_backdrop = true
	_on_press(_back_button, close)
	UIAnim.pop_in(_content)
