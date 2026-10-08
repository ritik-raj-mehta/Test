@tool
class_name LevelManager
extends RefCounted

static var current_level_data: LevelData = null
static var active_level_path: String = "res://game/assets/levels/level_001.tres"

static func _get_save_manager() -> SaveManager:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root:
		var registry: Node = main_loop.root.get_node_or_null("ServiceRegistry")
		if registry and registry.has_method("get_service"):
			return registry.get_service(&"save") as SaveManager
	return null

static func set_active_level_path(path: String) -> void:
	active_level_path = path
	var save := _get_save_manager()
	if save:
		save.set_value("active_level_path", path)
		save.save_game()
	else:
		var f := FileAccess.open("user://active_level_path.txt", FileAccess.WRITE)
		if f:
			f.store_string(path)
			f.close()

static func get_active_level_path() -> String:
	var save := _get_save_manager()
	if save:
		var val = save.get_value("active_level_path", "")
		if val != null and str(val) != "":
			var saved_str: String = str(val)
			if ResourceLoader.exists(saved_str) or FileAccess.file_exists(saved_str):
				active_level_path = saved_str
				return saved_str

	if FileAccess.file_exists("user://active_level_path.txt"):
		var f := FileAccess.open("user://active_level_path.txt", FileAccess.READ)
		if f:
			var saved_path = f.get_as_text().strip_edges()
			f.close()
			if saved_path != "" and (ResourceLoader.exists(saved_path) or FileAccess.file_exists(saved_path)):
				active_level_path = saved_path
				return saved_path
	return active_level_path

static func load_level_data(path: String) -> LevelData:
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is LevelData:
			current_level_data = res
			WorldThemeRegistry.set_current_theme(res.world_theme)
			set_active_level_path(path)
			return res

	# Fallback for mobile file paths or direct user:// paths
	if FileAccess.file_exists(path):
		var res = ResourceLoader.load(path)
		if res is LevelData:
			current_level_data = res
			WorldThemeRegistry.set_current_theme(res.world_theme)
			set_active_level_path(path)
			return res

	push_warning("LevelManager: Failed to load level data at path: '%s'" % path)
	return null

static func save_level_data(level_data: LevelData, path: String) -> bool:
	if not level_data:
		return false

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err = ResourceSaver.save(level_data, path)
	if err == OK:
		set_active_level_path(path)
		current_level_data = level_data
		return true
	else:
		push_error("LevelManager: Failed to save level to '%s', error code: %d" % [path, err])
		return false

static func get_all_level_paths() -> Array[String]:
	var paths_map: Dictionary = {}

	# Search directories in order of priority
	var search_dirs := ["res://game/assets/levels", "res://Levels", "user://Levels"]
	for dir_path in search_dirs:
		if DirAccess.dir_exists_absolute(dir_path):
			var dir := DirAccess.open(dir_path)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir():
						var clean_name = file_name.trim_suffix(".remap").trim_suffix(".import")
						if clean_name.ends_with(".tres") and not clean_name.to_lower().contains("template"):
							if not paths_map.has(clean_name):
								paths_map[clean_name] = dir_path + "/" + clean_name
					file_name = dir.get_next()
				dir.list_dir_end()

	var result: Array[String] = []
	for key in paths_map:
		result.append(paths_map[key])

	result.sort_custom(func(a, b): return a.get_file() < b.get_file())
	return result


static func get_next_level_path(current_path: String = "") -> String:
	if current_path == "":
		current_path = get_active_level_path()

	var all_levels = get_all_level_paths()
	var current_file = current_path.get_file()

	for i in range(all_levels.size()):
		if all_levels[i].get_file() == current_file:
			if i + 1 < all_levels.size():
				return all_levels[i + 1]
			break

	return ""

static func load_next_level() -> LevelData:
	var next_path = get_next_level_path(get_active_level_path())
	if next_path != "":
		return load_level_data(next_path)
	return null

static func get_default_level() -> LevelData:
	var active_path = get_active_level_path()
	if active_path != "" and (ResourceLoader.exists(active_path) or FileAccess.file_exists(active_path)):
		var loaded = load_level_data(active_path)
		if loaded:
			return loaded

	var all_paths = get_all_level_paths()
	if all_paths.size() > 0:
		var loaded = load_level_data(all_paths[0])
		if loaded:
			return loaded

	var empty_lvl := LevelData.new()
	empty_lvl.level_id = "level_001"
	empty_lvl.level_name = "Level 1"
	empty_lvl.world_theme = "world_1"
	return empty_lvl



static func bake_level_to_tscn(lvl_data: LevelData, save_path: String) -> Error:
	if not lvl_data:
		return ERR_INVALID_DATA

	var temp_root := Node2D.new()
	temp_root.name = "LevelRoot"

	# Build level nodes dynamically
	LevelLoader.load_level(lvl_data, temp_root)

	# Set owner recursively so PackedScene includes all child nodes & TileMap
	set_node_owner_recursive(temp_root, temp_root)

	# Pack into scene and save .tscn
	var packed_scene := PackedScene.new()
	var err = packed_scene.pack(temp_root)
	if err == OK:
		var dir_path = save_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		err = ResourceSaver.save(packed_scene, save_path)
		if err == OK:
			print("LevelManager: Successfully baked scene to '%s'" % save_path)
			if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
				var editor_iface = Engine.get_singleton("EditorInterface")
				if editor_iface and editor_iface.has_method("get_open_scenes") and editor_iface.has_method("reload_scene_from_path"):
					var open_scenes = editor_iface.get_open_scenes()
					if save_path in open_scenes:
						editor_iface.reload_scene_from_path(save_path)
	else:
		push_error("LevelManager: Failed to pack level scene: %d" % err)

	temp_root.free()
	return err

static func set_node_owner_recursive(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root_node
		# Only recurse into procedural container children, never into instantiated sub-scenes
		if child.scene_file_path == "":
			set_node_owner_recursive(child, root_node)


static func bake_level_to_res(lvl_data: LevelData, save_path: String) -> Error:
	if not lvl_data:
		return ERR_INVALID_DATA
	var dir_path = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err = ResourceSaver.save(lvl_data, save_path, ResourceSaver.FLAG_COMPRESS)
	if err == OK:
		print("LevelManager: Successfully exported binary .res to '%s'" % save_path)
	else:
		push_error("LevelManager: Failed to save binary .res to '%s', error: %d" % [save_path, err])
	return err


static func bake_all_levels_to_tscn() -> void:
	var paths = get_all_level_paths()
	for p in paths:
		var lvl = load_level_data(p)
		if lvl:
			var tscn_p = p.get_basename() + ".tscn"
			bake_level_to_tscn(lvl, tscn_p)
