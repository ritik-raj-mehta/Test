class_name ParallaxWorld
extends Node2D

const THEME_DIR: String = "res://game/assets/data/parallax/"
const STATIC_BG_KEY: StringName = &"static_bg"

@export var _controller: VerticalParallaxController
@export var static_bg: TextureRect

var _applied_world: String = ""


func setup(camera: Camera2D, player: Player, bus: Node) -> void:
	_controller.setup(camera, player, bus)


## Swaps each layer's sprite + start position for the given world. Layers are matched by layer_key.
func apply_theme(world_theme: String) -> void:
	if world_theme == _applied_world:
		return  # same world as the previous level, nothing to swap

	var path := THEME_DIR + world_theme + ".tres"
	var art: ParallaxTheme = load(path) as ParallaxTheme if ResourceLoader.exists(path) else null
	if art == null:
		push_warning("ParallaxWorld: no ParallaxTheme at %s, keeping scene textures." % path)
		return

	for layer in _controller.layers:
		if layer == null:
			continue
		if layer.layer_key == &"":
			layer.set_layer_texture(null)
			continue
		var tex := art.texture_for(layer.layer_key)
		layer.set_layer_texture(tex)
		layer.set_layer_position(art.position_for(layer.layer_key))

	# static_bg is a plain TextureRect (not a ParallaxLayerNew), so it is not in controller.layers.
	if static_bg:
		var bg_tex := art.texture_for(STATIC_BG_KEY)
		if bg_tex:
			static_bg.texture = bg_tex

	_applied_world = world_theme
