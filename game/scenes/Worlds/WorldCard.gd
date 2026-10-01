class_name WorldCard
extends Control

## WorldCard — one page of the Worlds carousel (preview art + number + name).
## Scene: WorldCard.tscn. Instanced once per world by WorldCarousel.

@export var _preview: TextureRect #= %WorldPreview
@export var _number: Label #= %WorldNumberLabel
@export var _name: Label #= %WorldNameLabel

func set_world(world: Dictionary, index: int) -> void:
	_number.text = "World %d" % (index + 1)
	_name.text = str(world.get("name", ""))
	var preview = world.get("preview")
	if preview is Texture2D:
		_preview.texture = preview
