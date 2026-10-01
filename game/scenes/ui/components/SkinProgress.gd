class_name SkinProgress
extends Control

## SkinProgress — star badge + progress bar. Presentational only: the caller
## (gameplay / popup) passes 0..1 values. Scene: SkinProgress.tscn

@export var _bar: TextureProgressBar #= %Bar

func set_value_instant(value: float) -> void:
	_bar.value = clampf(value, 0.0, 1.0)

func animate_to(from_value: float, to_value: float, duration: float = 0.6) -> void:
	_bar.value = clampf(from_value, 0.0, 1.0)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_bar, "value", clampf(to_value, 0.0, 1.0), duration)

func get_value() -> float:
	return _bar.value
