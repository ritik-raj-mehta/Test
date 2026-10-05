class_name SkinCatalog
extends RefCounted


## ============================================================
## SKIN DEFINITIONS
## ============================================================

const DEFAULT_ID: String = "zumpa_green"


const SKINS: Array = [

	{
		"id": "zumpa_green",
		"name": "Zumpa",
		"texture":
			"res://game/assets/sprites/single/ui/Characters/char1.png",
		"eat_right":
			"res://game/assets/sprites/single/ui/Characters/char1Right.png"
	},

	{
		"id": "sunny",
		"name": "Sunny",
		"texture":
			"res://game/assets/sprites/single/ui/Characters/char2.png",
		"eat_right":
			"res://game/assets/sprites/single/ui/Characters/char2Right.png"
	},

	{
		"id": "berry",
		"name": "Berry",
		"texture":
			"res://game/assets/sprites/single/ui/Characters/char3.png",
		"eat_right":
			"res://game/assets/sprites/single/ui/Characters/char3Right.png"
	},

	{
		"id": "skyblue",
		"name": "Sky",
		"texture":
			"res://game/assets/sprites/single/ui/Characters/char4.png",
		"eat_right":
			"res://game/assets/sprites/single/ui/Characters/char4Right.png"
	},

	{
		"id": "grape",
		"name": "Grape",
		"texture":
			"res://game/assets/sprites/single/ui/Characters/char5.png",
		"eat_right":
			"res://game/assets/sprites/single/ui/Characters/char5Right.png"
	}
]


## ============================================================
## BASIC LOOKUPS
## ============================================================

static func count() -> int:

	return SKINS.size()


static func at(index: int) -> Dictionary:

	return SKINS[
		wrapi(
			index,
			0,
			SKINS.size()
		)
	]


static func has_skin(id: String) -> bool:

	for skin in SKINS:

		if skin["id"] == id:
			return true

	return false


static func index_of(id: String) -> int:

	for i in SKINS.size():

		if SKINS[i]["id"] == id:
			return i

	return 0


## ============================================================
## GET SKIN DATA
## ============================================================

static func get_skin(id: String) -> Dictionary:

	if not has_skin(id):

		push_error(
			"SkinCatalog: Unknown character ID: "
			+ id
		)

		return SKINS[0]

	return SKINS[
		index_of(id)
	]


## ============================================================
## GET EATING TEXTURE
## ============================================================

static func get_eat_texture(
	id: String,
	side: String
) -> Texture2D:

	var skin := get_skin(id)

	var path: String = (
		skin.get(
			"eat_" + side,
			""
		)
	)

	if path.is_empty():

		push_error(
			"SkinCatalog: No eating texture for "
			+ id
			+ " / "
			+ side
		)

		return null

	if not ResourceLoader.exists(path):

		push_error(
			"SkinCatalog: Eating texture not found: "
			+ path
		)

		return null

	return load(path) as Texture2D
