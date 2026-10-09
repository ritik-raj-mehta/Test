@tool
extends SceneTree

func _init() -> void:
	print("========================================")
	print("STARTING LEVEL INTEGRITY CHECK")
	print("========================================")
	
	var level_paths: Array[String] = LevelManager.get_all_level_paths()
	print("Discovered level count via LevelManager: %d" % level_paths.size())
	
	var total_objects: int = 0
	var themes_found: Dictionary = {}
	var failed_levels: Array[String] = []
	var missing_object_ids: Dictionary = {}
	var missing_scenes: Dictionary = {}
	
	for path in level_paths:
		var lvl: LevelData = LevelManager.load_level_data(path)
		if lvl == null:
			print("❌ FAILED to load LevelData: %s" % path)
			failed_levels.append(path)
			continue
		
		var theme: String = lvl.world_theme
		themes_found[theme] = themes_found.get(theme, 0) + 1
		total_objects += lvl.objects.size()
		
		# Check each object in the level
		for obj in lvl.objects:
			if not ObjectRegistry.has_object(obj.object_id):
				missing_object_ids[obj.object_id] = missing_object_ids.get(obj.object_id, 0) + 1
			else:
				var entry: Dictionary = ObjectRegistry.get_entry(obj.object_id)
				var scene_path: String = entry.get("scene_path", "")
				if scene_path == "" or not ResourceLoader.exists(scene_path):
					missing_scenes[scene_path] = missing_scenes.get(scene_path, 0) + 1
	
	print("\n--- RESULTS ---")
	print("Total Valid Levels Loaded: %d / %d" % [level_paths.size() - failed_levels.size(), level_paths.size()])
	print("Failed Levels: %d" % failed_levels.size())
	if not failed_levels.is_empty():
		for f in failed_levels:
			print("  - %s" % f)
			
	print("Total Objects Across All Levels: %d" % total_objects)
	print("Themes Distribution:")
	for th in themes_found:
		print("  - %s: %d levels" % [th, themes_found[th]])
		
	print("Missing Object IDs in ObjectRegistry: %d" % missing_object_ids.size())
	for id in missing_object_ids:
		print("  - %s (referenced %d times)" % [id, missing_object_ids[id]])
		
	print("Missing Scene Paths: %d" % missing_scenes.size())
	for sp in missing_scenes:
		print("  - %s (referenced %d times)" % [sp, missing_scenes[sp]])
		
	# Check level editor template
	var template_path := "res://game/assets/levels/level_Template.tres"
	if ResourceLoader.exists(template_path):
		var tmpl: LevelData = ResourceLoader.load(template_path) as LevelData
		if tmpl:
			print("Level Template: VALID (objects: %d, theme: %s)" % [tmpl.objects.size(), tmpl.world_theme])
		else:
			print("Level Template: FAILED to cast to LevelData")
	else:
		print("Level Template: NOT FOUND at %s" % template_path)
		
	print("========================================")
	print("LEVEL INTEGRITY CHECK COMPLETE")
	print("========================================")
	quit(0 if failed_levels.is_empty() and missing_object_ids.is_empty() and missing_scenes.is_empty() else 1)
