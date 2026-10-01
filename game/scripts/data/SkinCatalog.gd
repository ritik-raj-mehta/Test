class_name SkinCatalog
extends RefCounted

## SkinCatalog — static skin definitions (data only, no save access).
## "color" drives the placeholder preview; add "texture"/"scene" keys when art exists.

const DEFAULT_ID: String = "zumpa_green"

const SKINS: Array = [
	{ "id": "zumpa_green", "name": "Zumpa",  "color": Color("#5ED68A"), "price": 0 },
	{ "id": "sunny",       "name": "Sunny",  "color": Color("#FFC83D"), "price": 500 },
	{ "id": "berry",       "name": "Berry",  "color": Color("#FF6F91"), "price": 800 },
	{ "id": "skyblue",     "name": "Sky",    "color": Color("#4FA9FF"), "price": 1200 },
	{ "id": "grape",       "name": "Grape",  "color": Color("#9B6BFF"), "price": 1500 },
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
