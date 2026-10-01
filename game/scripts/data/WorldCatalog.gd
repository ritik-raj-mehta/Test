class_name WorldCatalog
extends RefCounted

## WorldCatalog — world definitions + level numbering helpers.
## Level numbers are global: world 0 = levels 1..N, world 1 = N+1..2N (N = UIConfig.LEVELS_PER_WORLD).

const WORLDS: Array = [
	{ "id": "meadow", "name": "World 1", "preview": preload("res://game/assets/sprites/single/ui/World Card/World (1).png")},
	{ "id": "canyon", "name": "World 2", "preview": preload("res://game/assets/sprites/single/ui/World Card/World (2).png")},
	{ "id": "night",  "name": "World 3", "preview": preload("res://game/assets/sprites/single/ui/World Card/World (3).png")},
	{ "id": "night",  "name": "World 4", "preview": preload("res://game/assets/sprites/single/ui/World Card/World (4).png")},
	{ "id": "night",  "name": "World 5", "preview": preload("res://game/assets/sprites/single/ui/World Card/World (5).png")},
]

static func count() -> int:
	return WORLDS.size()

static func at(index: int) -> Dictionary:
	return WORLDS[clampi(index, 0, WORLDS.size() - 1)]

@warning_ignore("integer_division")
static func world_index_for_level(level: int) -> int:
	return clampi((maxi(level, 1) - 1) / UIConfig.LEVELS_PER_WORLD, 0, WORLDS.size() - 1)

static func first_level(world_index: int) -> int:
	return world_index * UIConfig.LEVELS_PER_WORLD + 1

static func stars_for(save: SaveManager, level: int) -> int:
	var prog: GameModels.ProgressionData = save.progression_data if save else null
	if prog == null:
		return 0
	return int(prog.level_stars.get("stage_%d" % level, 0))
