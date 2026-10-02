class_name SkinCatalog
extends RefCounted

## SkinCatalog — static skin definitions (data only, no save access).
## "color" drives the placeholder preview; add "texture"/"scene" keys when art exists.

const DEFAULT_ID: String = "zumpa_green"

const SKINS: Array = [
	{ "id": "zumpa_green", "name": "Zumpa", "texture": "res://game/assets/sprites/single/ui/Characters/char1.png","eat_right":"res://game/assets/sprites/single/ui/Characters/char1Right.png" },
	{ "id": "sunny",       "name": "Sunny", "texture": "res://game/assets/sprites/single/ui/Characters/char2.png","eat_right": "res://game/assets/sprites/single/ui/Characters/char2Right..png"},
	{ "id": "berry",       "name": "Berry", "texture": "res://game/assets/sprites/single/ui/Characters/char3.png","eat_right": "res://game/assets/sprites/single/ui/Characters/char3Right..png" },
	{ "id": "skyblue",     "name": "Sky", "texture": "res://game/assets/sprites/single/ui/Characters/char4.png" ,"eat_right": "res://game/assets/sprites/single/ui/Characters/char4Right..png"},
	{ "id": "grape",       "name": "Grape", "texture": "res://game/assets/sprites/single/ui/Characters/char5.png","eat_right": "res://game/assets/sprites/single/ui/Characters/char5Right..png" },
]

static func count() -> int:
	return SKINS.size()

static func at(index: int) -> Dictionary:
	return SKINS[wrapi(index, 0, SKINS.size())]

static func has_skin(id: String) -> bool:
	for s in SKINS:
		if s["id"] == id:
			return true
	return false

static func index_of(id: String) -> int:
	for i in SKINS.size():
		if SKINS[i]["id"] == id:
			return i
	return 0
	
static func get_eat_texture(id: String, side: String) -> Texture2D:
	var path: String = SKINS[index_of(id)].get("eat_" + side, "")
	return load(path) if path != "" and ResourceLoader.exists(path) else null
