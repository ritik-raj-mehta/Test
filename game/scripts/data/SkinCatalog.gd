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
		"texture":"res://game/assets/sprites/single/ui/Characters/char1.png",
		"eating_texture":"res://game/assets/sprites/single/ui/Characters/Eating/char1Eating.png",
		"goal_texture":"res://game/assets/sprites/single/ui/Characters/Goal/char1goal.png",
		"jump_texture":"res://game/assets/sprites/single/ui/Characters/Jumping/char1Jump.png"
	},

	{
		"id": "sunny",
		"name": "Sunny",
		"texture":"res://game/assets/sprites/single/ui/Characters/char2.png",
		"eating_texture":"res://game/assets/sprites/single/ui/Characters/Eating/char2Eating .png",
		"goal_texture":"res://game/assets/sprites/single/ui/Characters/Goal/char2goal.png",
		"jump_texture":"res://game/assets/sprites/single/ui/Characters/Jumping/char2Jump.png"
	},

	{
		"id": "berry",
		"name": "Berry",
		"texture":"res://game/assets/sprites/single/ui/Characters/char3.png",
		"eating_texture":"res://game/assets/sprites/single/ui/Characters/Eating/char3Eating.png",
		"goal_texture":"res://game/assets/sprites/single/ui/Characters/Goal/char3goal.png",
		"jump_texture":"res://game/assets/sprites/single/ui/Characters/Jumping/char3Jump.png",
	},

	{
		"id": "skyblue",
		"name": "Sky",
		"texture":"res://game/assets/sprites/single/ui/Characters/char4.png",
		"eating_texture":"res://game/assets/sprites/single/ui/Characters/Eating/char4Eating.png",
		"goal_texture":"res://game/assets/sprites/single/ui/Characters/Goal/char4goal.png",
		"jump_texture":"res://game/assets/sprites/single/ui/Characters/Jumping/char4Jump.png"
	},

	{
		"id": "grape",
		"name": "Grape",
		"texture":"res://game/assets/sprites/single/ui/Characters/char5.png",		
		"eating_texture":"res://game/assets/sprites/single/ui/Characters/Eating/char5Eating.png",
		"goal_texture":"res://game/assets/sprites/single/ui/Characters/Goal/char5goal.png",
		"jump_texture":"res://game/assets/sprites/single/ui/Characters/Jumping/char5Jump.png"
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


## ============================================================
## GET TAP / RELEASE / EATING TEXTURES
## ============================================================

static func _load_skin_texture(
	id: String,
	key: String
) -> Texture2D:

	var skin := get_skin(id)
	var path: String = skin.get(key, "")

	if path.is_empty():
		return null

	if not ResourceLoader.exists(path):
		push_error(
			"SkinCatalog: Texture not found: " + path
		)
		return null

	return load(path) as Texture2D


static func get_eating_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "eating_texture")


static func get_goal_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "goal_texture")


static func get_jump_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "jump_texture")


static func get_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "texture")


static func get_eating_frames(id: String) -> Array[Texture2D]:
	var tex: Texture2D = get_eating_texture(id)
	var frames: Array[Texture2D] = []
	if tex == null:
		return frames

	var w: float = tex.get_width()
	var h: float = tex.get_height()

	if w > h and h > 0:
		var frame_count: int = int(round(w / h))
		var frame_width: float = w / float(frame_count)
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_width, 0, frame_width, h)
			frames.append(atlas)
	else:
		frames.append(tex)

	return frames


static func get_tap_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "tap_texture")


static func get_release_texture(id: String) -> Texture2D:
	return _load_skin_texture(id, "release_texture")
