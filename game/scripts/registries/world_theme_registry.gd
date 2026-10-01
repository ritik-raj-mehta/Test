@tool
extends RefCounted
class_name WorldThemeRegistry

## Centralized registry for all world environment visual themes.
## Manages background textures, wall styles, tile attributes, obstacle textures, fruit goals, and cached TileSet generation.

static var _current_theme_id: String = "world_1"

static var _themes: Dictionary = {
	"world_1": {
		"id": "world_1",
		"name": "World 1 - Forest Hills",
		"background": "res://game/assets/sprites/backgrounds/Bg1.png",
		"wall_texture": "res://game/assets/sprites/ENV/Rectangle 155.png",
		"platform_texture": "res://game/assets/sprites/atlases/tiles/Tile1.png",
		"tile_size": Vector2i(32, 32),
		"default_atlas_coords": Vector2i(1, 1),
		"theme_color": Color(0.2, 0.8, 0.4, 1.0),
		"gear_texture": "res://game/assets/sprites/obstacles/Gear1.png",
		"gear_rod_texture": "res://game/assets/sprites/obstacles/GearRode1.png",
		"falling_stone_texture": "res://game/assets/sprites/obstacles/Stone1.png",
		"falling_stone_spike_texture": "res://game/assets/sprites/obstacles/SpikeStone1.png",
		"fruit_texture": "res://game/assets/sprites/obstacles/Fruit1.png"
	},
	"world_2": {
		"id": "world_2",
		"name": "World 2 - Desert Sunset",
		"background": "res://game/assets/sprites/backgrounds/Bg2.png",
		"wall_texture": "res://game/assets/sprites/ENV/Rectangle 155.png",
		"platform_texture": "res://game/assets/sprites/atlases/tiles/Tile2.png",
		"tile_size": Vector2i(32, 32),
		"default_atlas_coords": Vector2i(1, 1),
		"theme_color": Color(0.9, 0.6, 0.2, 1.0),
		"gear_texture": "res://game/assets/sprites/obstacles/Gear2.png",
		"gear_rod_texture": "res://game/assets/sprites/obstacles/GearRode2.png",
		"falling_stone_texture": "res://game/assets/sprites/obstacles/Stone2.png",
		"falling_stone_spike_texture": "res://game/assets/sprites/obstacles/SpikeStone2.png",
		"fruit_texture": "res://game/assets/sprites/obstacles/Fruit2.png"
	},
	"world_3": {
		"id": "world_3",
		"name": "World 3 - Cyber Night",
		"background": "res://game/assets/sprites/backgrounds/Bg3.png",
		"wall_texture": "res://game/assets/sprites/ENV/Rectangle 155.png",
		"platform_texture": "res://game/assets/sprites/atlases/tiles/Tile3.png",
		"tile_size": Vector2i(32, 32),
		"default_atlas_coords": Vector2i(11, 1),
		"theme_color": Color(0.2, 0.6, 1.0, 1.0),
		"gear_texture": "res://game/assets/sprites/obstacles/Gear3.png",
		"gear_rod_texture": "res://game/assets/sprites/obstacles/GearRode3.png",
		"falling_stone_texture": "res://game/assets/sprites/obstacles/Stone3.png",
		"falling_stone_spike_texture": "res://game/assets/sprites/obstacles/SpikeStone3.png",
		"fruit_texture": "res://game/assets/sprites/obstacles/Fruit3.png"
	},
	"world_4": {
		"id": "world_4",
		"name": "World 4 - Mystic Caves",
		"background": "res://game/assets/sprites/backgrounds/Bg4.png",
		"wall_texture": "res://game/assets/sprites/ENV/Rectangle 155.png",
		"platform_texture": "res://game/assets/sprites/atlases/tiles/Tile4.png",
		"tile_size": Vector2i(32, 32),
		"default_atlas_coords": Vector2i(1, 1),
		"theme_color": Color(0.8, 0.3, 0.8, 1.0),
		"gear_texture": "res://game/assets/sprites/obstacles/Gear4.png",
		"gear_rod_texture": "res://game/assets/sprites/obstacles/GearRode4.png",
		"falling_stone_texture": "res://game/assets/sprites/obstacles/Stone4.png",
		"falling_stone_spike_texture": "res://game/assets/sprites/obstacles/SpikeStone4.png",
		"fruit_texture": "res://game/assets/sprites/obstacles/Fruit4.png"
	},
	"world_5": {
		"id": "world_5",
		"name": "World 5 - Magma Core",
		"background": "res://game/assets/sprites/backgrounds/Bg5.png",
		"wall_texture": "res://game/assets/sprites/ENV/Rectangle 155.png",
		"platform_texture": "res://game/assets/sprites/atlases/tiles/Tile5.png",
		"tile_size": Vector2i(32, 32),
		"default_atlas_coords": Vector2i(1, 1),
		"theme_color": Color(0.95, 0.25, 0.2, 1.0),
		"gear_texture": "res://game/assets/sprites/obstacles/Gear5.png",
		"gear_rod_texture": "res://game/assets/sprites/obstacles/GearRode5.png",
		"falling_stone_texture": "res://game/assets/sprites/obstacles/Stone5.png",
		"falling_stone_spike_texture": "res://game/assets/sprites/obstacles/SpikeStone5.png",
		"fruit_texture": "res://game/assets/sprites/obstacles/Fruit5.png"
	}
}

static var _tileset_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}

static func set_current_theme(theme_id: String) -> void:
	if _themes.has(theme_id):
		_current_theme_id = theme_id
	elif theme_id != "":
		_current_theme_id = "world_1"

static func get_current_theme() -> String:
	return _current_theme_id

static func resolve_texture_path(path: String) -> String:
	if ResourceLoader.exists(path):
		return path
	var single_fallback = path.replace("res://game/assets/sprites/", "res://game/assets/sprites/single/").replace("res://Sprite/", "res://game/assets/sprites/single/")
	if ResourceLoader.exists(single_fallback):
		return single_fallback
	var tile_fallback = path.replace("res://tiles/", "res://game/assets/tiles/")
	if ResourceLoader.exists(tile_fallback):
		return tile_fallback
	var sprite_fallback = path.replace("res://Sprite/", "res://game/assets/sprites/")
	if ResourceLoader.exists(sprite_fallback):
		return sprite_fallback
	return path

static func register_theme(theme_id: String, display_name: String, bg_path: String, wall_path: String, platform_tile_path: String, tile_sz: Vector2i = Vector2i(16, 16), default_atlas: Vector2i = Vector2i(1, 1), theme_color: Color = Color.WHITE) -> void:
	_themes[theme_id] = {
		"id": theme_id,
		"name": display_name,
		"background": bg_path,
		"wall_texture": wall_path,
		"platform_texture": platform_tile_path,
		"tile_size": tile_sz,
		"default_atlas_coords": default_atlas,
		"theme_color": theme_color
	}
	_tileset_cache.erase(theme_id)

static func set_theme_tile_size(theme_id: String, tile_sz: Vector2i) -> void:
	if _themes.has(theme_id):
		_themes[theme_id]["tile_size"] = tile_sz
		_tileset_cache.erase(theme_id)

static func get_all_themes() -> Dictionary:
	return _themes

static func get_theme_ids() -> Array[String]:
	var keys: Array[String] = []
	for k in _themes.keys():
		keys.append(str(k))
	return keys

static func get_theme(theme_id: String) -> Dictionary:
	if _themes.has(theme_id):
		return _themes[theme_id]
	if _themes.has(_current_theme_id):
		return _themes[_current_theme_id]
	return _themes.get("world_1", {})

static func has_theme(theme_id: String) -> bool:
	return _themes.has(theme_id)

static func get_asset_path(theme_id: String, key: String, fallback: String = "") -> String:
	var theme_info = get_theme(theme_id)
	if theme_info.has(key):
		return resolve_texture_path(str(theme_info[key]))
	return resolve_texture_path(fallback)

static func get_asset_texture(theme_id: String, key: String, fallback_path: String = "") -> Texture2D:
	var path = get_asset_path(theme_id, key, fallback_path)
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			_texture_cache[path] = tex
			return tex
	return null

static func get_background_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "background", "res://game/assets/sprites/backgrounds/Bg1.png")

static func get_gear_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "gear_texture", "res://game/assets/sprites/obstacles/Gear1.png")

static func get_gear_rod_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "gear_rod_texture", "res://game/assets/sprites/obstacles/GearRode1.png")

static func get_falling_stone_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "falling_stone_texture", "res://game/assets/sprites/obstacles/Stone1.png")

static func get_falling_stone_spike_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "falling_stone_spike_texture", "res://game/assets/sprites/obstacles/SpikeStone1.png")

static func get_fruit_texture(theme_id: String) -> Texture2D:
	return get_asset_texture(theme_id, "fruit_texture", "res://game/assets/sprites/obstacles/Fruit1.png")


static func create_tileset_for_theme(theme_id: String) -> TileSet:
	if _tileset_cache.has(theme_id):
		return _tileset_cache[theme_id] as TileSet

	var theme_info = get_theme(theme_id)
	var t_size: Vector2i = theme_info.get("tile_size", Vector2i(16, 16))
	var tileset := TileSet.new()
	tileset.tile_size = t_size

	# 1. Add physics collision layer FIRST
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var tex_path: String = resolve_texture_path(theme_info.get("platform_texture", "res://game/assets/tiles/Terrain (16x16).png"))
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		var img: Image = null
		if tex:
			img = tex.get_image()
			if img and img.is_compressed():
				img.decompress()

		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = tex
		atlas_source.texture_region_size = t_size

		# 2. Add atlas source to TileSet FIRST
		tileset.add_source(atlas_source, 0)

		# 3. Populate tiles across the texture sheet
		var tex_size = tex.get_size()
		var cols = max(1, int(tex_size.x / float(t_size.x)))
		var rows = max(1, int(tex_size.y / float(t_size.y)))

		var half_w = float(t_size.x) / 2.0
		var half_h = float(t_size.y) / 2.0

		for y in range(rows):
			for x in range(cols):
				var coords := Vector2i(x, y)
				atlas_source.create_tile(coords)
				var tile_data = atlas_source.get_tile_data(coords, 0)
				if tile_data:
					var poly = get_tile_collision_polygon(img, coords, t_size, half_w, half_h)
					if poly.size() >= 3:
						tile_data.add_collision_polygon(0)
						tile_data.set_collision_polygon_points(0, 0, poly)

	_tileset_cache[theme_id] = tileset
	return tileset

static func clear_cache() -> void:
	_tileset_cache.clear()

static func get_tile_collision_polygon(img: Image, coords: Vector2i, t_size: Vector2i, half_w: float, half_h: float) -> PackedVector2Array:
	if not img:
		return PackedVector2Array([
			Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
			Vector2(half_w, half_h), Vector2(-half_w, half_h)
		])

	var start_x = coords.x * t_size.x
	var start_y = coords.y * t_size.y

	if start_x + t_size.x > img.get_width() or start_y + t_size.y > img.get_height():
		return PackedVector2Array()

	# Sample transparency & color at key points inside tile cell
	var margin = int(clamp(float(t_size.x) * 0.15, 1.0, 4.0))
	var tl_solid = is_pixel_solid(img, start_x + margin, start_y + margin)
	var tr_solid = is_pixel_solid(img, start_x + t_size.x - 1 - margin, start_y + margin)
	var bl_solid = is_pixel_solid(img, start_x + margin, start_y + t_size.y - 1 - margin)
	var br_solid = is_pixel_solid(img, start_x + t_size.x - 1 - margin, start_y + t_size.y - 1 - margin)
	var tm_solid = is_pixel_solid(img, start_x + t_size.x / 2, start_y + margin)

	var solid_count = (1 if tl_solid else 0) + (1 if tr_solid else 0) + (1 if bl_solid else 0) + (1 if br_solid else 0)

	if solid_count == 0:
		return PackedVector2Array() # Blank transparent tile -> No collision

	# Detect Triangle Collision Shapes:
	# 1. Top-Right Ascending Slope Triangle (bottom-left transparent)
	if tr_solid and bl_solid and br_solid and not tl_solid:
		return PackedVector2Array([Vector2(-half_w, half_h), Vector2(half_w, -half_h), Vector2(half_w, half_h)])

	# 2. Top-Left Descending Slope Triangle (top-right transparent)
	if tl_solid and bl_solid and br_solid and not tr_solid:
		return PackedVector2Array([Vector2(-half_w, -half_h), Vector2(-half_w, half_h), Vector2(half_w, half_h)])

	# 3. Inverted Top-Right Slope Triangle (bottom-right transparent)
	if tl_solid and tr_solid and bl_solid and not br_solid:
		return PackedVector2Array([Vector2(-half_w, -half_h), Vector2(half_w, -half_h), Vector2(-half_w, half_h)])

	# 4. Inverted Top-Left Slope Triangle (bottom-left transparent)
	if tl_solid and tr_solid and br_solid and not bl_solid:
		return PackedVector2Array([Vector2(-half_w, -half_h), Vector2(half_w, -half_h), Vector2(half_w, half_h)])

	# 5. Upward Peak / Roof Triangle (tm_solid, bl_solid, br_solid)
	if tm_solid and bl_solid and br_solid and not tl_solid and not tr_solid:
		return PackedVector2Array([Vector2(0, -half_h), Vector2(half_w, half_h), Vector2(-half_w, half_h)])

	# Default: Full Square
	return PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w, half_h), Vector2(-half_w, half_h)
	])

static func is_pixel_solid(img: Image, px: int, py: int) -> bool:
	if px < 0 or px >= img.get_width() or py < 0 or py >= img.get_height():
		return false
	var color = img.get_pixel(px, py)
	if color.a < 0.15:
		return false
	# Dark gray background check (RGB ~ 0.2, 0.2, 0.2)
	if color.r > 0.15 and color.r < 0.35 and color.g > 0.15 and color.g < 0.35 and color.b > 0.15 and color.b < 0.35:
		return false
	return true
