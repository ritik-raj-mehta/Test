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

func set_badge_skin(skin_data: Dictionary) -> void:
	var badge = _bar.get_node_or_null("Badge") as TextureRect
	if badge:
		# Clear existing children (in case it gets called multiple times)
		for child in badge.get_children():
			child.queue_free()
		
		# Instantiate a TextureRect for the character sprite if it exists
		if skin_data.has("texture") and ResourceLoader.exists(skin_data["texture"]):
			var tex := load(skin_data["texture"]) as Texture2D
			if tex:
				badge.texture = tex
				# var tex_rect = TextureRect.new()
				# tex_rect.texture = tex
				# tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				# tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				# tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				# badge.add_child(tex_rect)
