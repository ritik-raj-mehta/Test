class_name ParallaxTheme
extends Resource

@export var parallax_data: Array[ParallaxLayerData] = []


func data_for(key: StringName) -> ParallaxLayerData:
	for data in parallax_data:
		if data.layer_key == key:
			return data

	return null

func texture_for(key: StringName) -> Texture2D:
	var data = data_for(key)
	return data.texture if data else null

func position_for(key: StringName) -> Vector2:
	var data = data_for(key)
	return data.position if data else Vector2.ZERO

