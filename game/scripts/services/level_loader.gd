@tool
class_name LevelLoader

static var _player_prefab_cache: PackedScene = null
static var _goal_prefab_cache: PackedScene = null

static func get_player_prefab() -> PackedScene:
	if _player_prefab_cache:
		return _player_prefab_cache
	var path := "res://game/scenes/gameplay/Player.tscn"
	if ResourceLoader.exists(path):
		_player_prefab_cache = load(path)
		return _player_prefab_cache
	if ResourceLoader.exists("res://Scenes/Player.tscn"):
		_player_prefab_cache = load("res://Scenes/Player.tscn")
		return _player_prefab_cache
	return null

static func get_goal_prefab() -> PackedScene:
	if _goal_prefab_cache:
		return _goal_prefab_cache
	var path := "res://game/scenes/obstacles/Goal.tscn"
	if ResourceLoader.exists(path):
		_goal_prefab_cache = load(path) as PackedScene
		return _goal_prefab_cache
	return null

static func prewarm_prefabs() -> void:
	get_player_prefab()
	get_goal_prefab()

static func load_level(level_data: LevelData, container: Node) -> CharacterBody2D:
	if not level_data or not container:
		push_error("LevelLoader: Invalid level_data or container")
		return null

	# Clear previous nodes
	for child in container.get_children():
		child.queue_free()

	# Set active theme in registry
	WorldThemeRegistry.set_current_theme(level_data.world_theme)
	var theme_info = WorldThemeRegistry.get_theme(level_data.world_theme)

	# 1. Spawn Player
	var player_scene = get_player_prefab()
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D if player_scene else CharacterBody2D.new()
	player.z_index = 10
	player.visible = true
	player.position = level_data.player_start

	if player.has_node("Sprite2D"):
		var p_sprite = player.get_node("Sprite2D") as Sprite2D
		if p_sprite:
			p_sprite.visible = true
			p_sprite.z_index = 10

	# Apply world theme background texture to Player scene
	var bg_tex = WorldThemeRegistry.get_background_texture(level_data.world_theme)
	if bg_tex:
		var p_bg: TextureRect = null
		if player.has_node("BgAnchor/TextureRect"):
			p_bg = player.get_node("BgAnchor/TextureRect") as TextureRect
		elif player.has_node("Camera2D/TextureRect"):
			p_bg = player.get_node("Camera2D/TextureRect") as TextureRect
		elif player.has_node("TextureRect"):
			p_bg = player.get_node("TextureRect") as TextureRect

		if p_bg:
			p_bg.texture = bg_tex
			p_bg.z_index = -100
			p_bg.z_as_relative = false

	# Apply Camera2D drag settings from LevelData
	apply_camera_drag_settings(level_data, player)

	# Determine fall threshold (lowest Y position in level + padding)
	var lowest_y: float = level_data.player_start.y + 800.0
	for obj in level_data.objects:
		if obj.position.y > lowest_y:
			lowest_y = obj.position.y
	player.set("FALL_Y", lowest_y + 300.0)

	container.add_child(player)

	# 2. Spawn TileMap / TileMapLayer World Terrain
	spawn_world_tilemap(level_data, container)

	# 3. Spawn Level Objects
	for obj_data in level_data.objects:
		spawn_object(obj_data, container, level_data.world_theme)

	return player

static func spawn_world_tilemap(level_data: LevelData, container: Node) -> Node:
	var theme_info = WorldThemeRegistry.get_theme(level_data.world_theme)
	var def_atlas: Vector2i = theme_info.get("default_atlas_coords", Vector2i(1, 1))
	var t_size: Vector2i = theme_info.get("tile_size", Vector2i(16, 16))

	var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var tile_offset_x: float = fmod(center_x, 48.0)

	var tilemap_layer := TileMapLayer.new()
	tilemap_layer.name = "WorldTileMap"
	tilemap_layer.tile_set = WorldThemeRegistry.create_tileset_for_theme(level_data.world_theme)
	tilemap_layer.position = Vector2(tile_offset_x, 0)
	var scale_factor: float = 48.0 / float(t_size.x) if t_size.x > 0 else 3.0
	tilemap_layer.scale = Vector2(scale_factor, scale_factor)
	tilemap_layer.z_index = 150

	# Render saved tile map cells
	level_data.migrate_tile_data_if_needed()
	var pt_size: int = level_data.packed_tiles.size()
	if pt_size >= 4:
		for i in range(0, pt_size, 4):
			var cell := Vector2i(level_data.packed_tiles[i], level_data.packed_tiles[i + 1])
			var atlas_x: int = level_data.packed_tiles[i + 2]
			var atlas_y: int = level_data.packed_tiles[i + 3]
			tilemap_layer.set_cell(cell, 0, Vector2i(atlas_x, atlas_y))

	container.add_child(tilemap_layer)
	return tilemap_layer

static func spawn_object(obj_data: ObjectData, container: Node, world_theme: String = "") -> Node2D:
	if not obj_data:
		return null

	var node: Node2D = ObjectRegistry.instantiate_object(obj_data.object_id)
	if not node:
		push_error("LevelLoader: Failed to instantiate object_id '%s'" % obj_data.object_id)
		return null

	node.position = obj_data.position
	node.rotation_degrees = obj_data.rotation
	node.scale = obj_data.scale

	# Apply theme
	var target_theme = world_theme if world_theme != "" else WorldThemeRegistry.get_current_theme()
	if "world_theme" in node:
		node.set("world_theme", target_theme)
	if node.has_method("apply_theme"):
		node.call("apply_theme", target_theme)

	# Apply custom properties
	for prop_name in obj_data.properties:
		if prop_name in node:
			node.set(prop_name, obj_data.properties[prop_name])
	if node.has_method("update_shape_size"):
		node.call("update_shape_size")
	if node.has_method("update_components"):
		node.call("update_components")
	# Generate a clean, unique Godot node name without '@' or invalid characters
	var raw_name = obj_data.object_id.capitalize().replace(" ", "").replace("_", "")
	if raw_name == "":
		raw_name = "Object"

	var clean_name = raw_name
	var count = 1
	while container.has_node(clean_name):
		count += 1
		clean_name = "%s_%d" % [raw_name, count]

	node.name = clean_name
	container.add_child(node)
	return node



# static func spawn_boundaries(level_data: LevelData, container: Node, theme_info: Dictionary) -> void:
# 	var wall_path: String = theme_info.get("wall_texture", "res://Sprite/LVLFrames/Union.png")
# 	var wall_texture: Texture2D = null
# 	if ResourceLoader.exists(wall_path):
# 		wall_texture = load(wall_path)
# 
# 	# Calculate vertical range needed for boundaries
# 	var min_y: float = -level_data.level_size.y
# 	var max_y: float = 2000.0
# 
# 	for obj in level_data.objects:
# 		if obj.position.y < min_y:
# 			min_y = obj.position.y - 1000.0
# 		if obj.position.y > max_y:
# 			max_y = obj.position.y + 1000.0
# 
# 	var segment_height: float = 2343.0
# 	var col_shape_size: Vector2 = Vector2(465, 2343)
# 
# 	var current_y: float = max_y
# 	while current_y >= min_y:
# 		# Left Wall Segment
# 		var left_wall := StaticBody2D.new()
# 		left_wall.name = "LeftWall_" + str(int(current_y))
# 		left_wall.position = Vector2(-255, current_y)
# 
# 		if wall_texture:
# 			var left_sprite := Sprite2D.new()
# 			left_sprite.texture = wall_texture
# 			left_wall.add_child(left_sprite)
# 
# 		var left_col := CollisionShape2D.new()
# 		var left_rect := RectangleShape2D.new()
# 		left_rect.size = col_shape_size
# 		left_col.shape = left_rect
# 		left_col.position = Vector2(69, -15)
# 		left_wall.add_child(left_col)
# 
# 		container.add_child(left_wall)
# 
# 		# Right Wall Segment
# 		var right_wall := StaticBody2D.new()
# 		right_wall.name = "RightWall_" + str(int(current_y))
# 		right_wall.position = Vector2(1320, current_y)
# 		right_wall.rotation = PI
# 
# 		if wall_texture:
# 			var right_sprite := Sprite2D.new()
# 			right_sprite.texture = wall_texture
# 			right_wall.add_child(right_sprite)
# 
# 		var right_col := CollisionShape2D.new()
# 		var right_rect := RectangleShape2D.new()
# 		right_rect.size = col_shape_size
# 		right_col.shape = right_rect
# 		right_col.position = Vector2(60, -8)
# 		right_wall.add_child(right_col)
# 
# 		container.add_child(right_wall)
# 
# 		current_y -= segment_height

static func apply_camera_drag_settings(level_data: LevelData, player: Node2D) -> void:
	CameraDragState.reset()
	if not level_data or not player:
		return
	if player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D") as Camera2D
		if cam:
			cam.drag_horizontal_enabled = level_data.camera_drag_horizontal_enabled
			cam.drag_vertical_enabled = level_data.camera_drag_vertical_enabled
			cam.drag_horizontal_offset = level_data.camera_drag_horizontal_offset
			cam.drag_vertical_offset = level_data.camera_drag_vertical_offset
			cam.drag_left_margin = level_data.camera_drag_left_margin
			cam.drag_top_margin = level_data.camera_drag_top_margin
			cam.drag_right_margin = level_data.camera_drag_right_margin
			cam.drag_bottom_margin = level_data.camera_drag_bottom_margin
			CameraDragState.cache_baseline(cam)
