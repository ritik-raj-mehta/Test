class_name BackdropSet
extends Resource

## One blurred background per world, same order as WorldCatalog.
## Assign AtlasTextures (or any Texture2D) here in the inspector.
@export var world_textures: Array[Texture2D] = []

func texture_for(world_index: int) -> Texture2D:
	if world_index < 0 or world_index >= world_textures.size():
		return null
	return world_textures[world_index]