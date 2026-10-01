class_name LevelLauncher
extends RefCounted

## LevelLauncher — the single "start this level" entry point used by Home, Worlds
## and Level Completed. Gameplay reads the level with:
##     save.get_value(UIConfig.SELECTED_LEVEL_KEY, save.get_level())
## Returns false (and logs) while Gameplay.tscn does not exist yet.

static func start(level: int, scene: SceneManager, save: SaveManager, bus: Node, logger: Node) -> bool:
	if scene == null:
		return false
	if not ResourceLoader.exists(ScenePaths.GAMEPLAY):
		if logger:
			logger.warn("LevelLauncher: Gameplay scene not found", { "path": ScenePaths.GAMEPLAY, "level": level })
		else:
			push_warning("LevelLauncher: Gameplay scene not found: %s" % ScenePaths.GAMEPLAY)
		return false
	if save:
		save.set_value(UIConfig.SELECTED_LEVEL_KEY, level)
	var lvl_path = "res://game/assets/levels/level_%03d.tres" % level
	if not ResourceLoader.exists(lvl_path) and not FileAccess.file_exists(lvl_path):
		lvl_path = "res://Levels/level_%03d.tres" % level
	LevelManager.set_active_level_path(lvl_path)
	LevelManager.load_level_data(lvl_path)

	if bus:
		bus.level_started.emit(str(level))
	scene.go_to(ScenePaths.GAMEPLAY)
	return true
