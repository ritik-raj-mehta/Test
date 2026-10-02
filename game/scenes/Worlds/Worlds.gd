class_name WorldsScene
extends AppView

## WorldsScene — world selector (snap carousel) + level grid. Layout: Worlds.tscn
## Swipe/drag the world card or use the arrows to change world; the level grid pops in
## with a staggered scale animation once the carousel settles on a world.
## The level grid itself (LevelGrid.gd) is also vertically drag-scrollable.
## Tiles are LevelTile.tscn instances (assign `tile_scene` in the inspector).

## Fire this (e.g. forwarded from the game bus) whenever a level's progress changes —
## newly unlocked, completed, star count changed — so the grid updates without a full rebuild:
##   GameBus.level_progress_changed.connect(worlds_scene.level_progress_changed.emit)
signal level_progress_changed(level: int, stars: int)

const POP_STAGGER := 0.045  ## seconds between each tile's pop-in, row-major

@export var tile_scene: PackedScene

@export var _carousel: WorldCarousel #= %WorldCarousel
@export var _grid: LevelGrid #= %LevelGrid
@export var _prev_button: BaseButton #= %PrevButton
@export var _next_button: BaseButton #= %NextButton
@export var _back_button: BaseButton #= %BackButton
@export var background: TextureRect 
@export var _blur_bg_list: Array[Texture] 

var _world_index: int = 0

func _on_ready() -> void:
	_world_index = WorldCatalog.world_index_for_level(_save.get_level() if _save else 1)

	var worlds: Array = []
	for i in WorldCatalog.count():
		worlds.append(WorldCatalog.at(i))
	_carousel.build(worlds, _world_index)
	_carousel.selected.connect(_on_world_selected)
	_carousel.settled.connect(_on_world_settled)

	_grid.tile_chosen.connect(_on_tile_chosen)
	level_progress_changed.connect(_on_level_progress_changed)

	_on_press(_prev_button, _carousel.previous)
	_on_press(_next_button, _carousel.next)
	_on_press(_back_button, close)
	_update_arrows()
	_rebuild_grid(false)  # first world: show immediately, no pop-in
	_Setup_Bg_at_first_world()

func _Setup_Bg_at_first_world() -> void:
	var world_index = 0
	var current_level = _save.get_level() 
	if current_level <= 10:
		world_index = 0
	elif current_level <= 20:
		world_index = 1
	elif current_level <= 30:
		world_index = 2	
	elif current_level <= 40:
		world_index = 3
	elif current_level <= 50:
		world_index = 4
	else:
		world_index = 0

	select_bg_for_world(world_index)

func select_bg_for_world(index: int) -> void:
	if index < _blur_bg_list.size():
		background.texture = _blur_bg_list[index]
	else:
		background.texture = null
		_logger.warn("WorldsScene: no blur background for world index ", index)

func _on_world_selected(index: int) -> void:
	_world_index = index
	_update_arrows()

func _on_world_settled(_index: int) -> void:
	_rebuild_grid(true)
	# background.texture = _blur_bg_list[_world_index] if _world_index < _blur_bg_list.size() else null
	select_bg_for_world(_world_index)

func _update_arrows() -> void:
	_prev_button.disabled = _world_index == 0
	_next_button.disabled = _world_index == WorldCatalog.count() - 1
	_prev_button.modulate.a = 0.35 if _prev_button.disabled else 1.0
	_next_button.modulate.a = 0.35 if _next_button.disabled else 1.0

func _rebuild_grid(animate: bool) -> void:
	var first := WorldCatalog.first_level(_world_index)
	var levels: Array = []
	for level in range(first, first + UIConfig.LEVELS_PER_WORLD):
		levels.append({
			"level": level,
			"state": _state_for(level),
			"stars": WorldCatalog.stars_for(_save, level),
		})
	var tiles := _grid.build(levels)
	if animate:
		for i in tiles.size():
			tiles[i].pop_in(i * POP_STAGGER)

## LOCKED / CURRENT / COMPLETED / OPEN — see LevelTile.State.
func _state_for(level: int) -> int:
	var unlocked: int = _save.progression_data.unlocked_levels if _save else 1
	var current: int = _save.get_level() if _save else 1
	if level > unlocked:
		return LevelTile.State.LOCKED
	if level == current:
		return LevelTile.State.CURRENT
	if WorldCatalog.stars_for(_save, level) > 0:
		return LevelTile.State.COMPLETED
	return LevelTile.State.OPEN

func _on_tile_chosen(level: int) -> void:
	_click()
	await close()  # popup lives in the persistent UIManager, so close it before the scene reloads
	LevelLauncher.start(level, _scene, _save, _bus, _logger)

## Refreshes one tile in place (no rebuild / no pop-in) when progress changes elsewhere,
## e.g. after finishing a level. Also re-checks the tile that was CURRENT before, since
## unlocking a level moves which tile counts as "current".
func _on_level_progress_changed(level: int, _stars: int) -> void:
	var first := WorldCatalog.first_level(_world_index)
	var last := first + UIConfig.LEVELS_PER_WORLD - 1
	for lvl in range(first, last + 1):
		if lvl == level or lvl == (_save.get_level() if _save else 1):
			_grid.refresh_tile(lvl, _state_for(lvl), WorldCatalog.stars_for(_save, lvl))
