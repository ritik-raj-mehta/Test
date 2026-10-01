class_name LevelGrid
extends Control

## LevelGrid — custom draggable level-number grid (see worlds_Reff.png).
## Lays tiles out in fixed-size rows of `columns`; a shorter final row is centred
## instead of left-aligned, matching the reference (e.g. 4 / 4 / 2).
## The whole grid is vertically drag-scrollable (mouse + touch), with elastic
## overscroll and a spring-back snap when released past the edges.
##
## Tile states (locked / current / open) and progress (stars) live on LevelTile;
## this control only arranges tiles and forwards their signals.

signal tile_chosen(level: int)

@export var tile_scene: PackedScene
@export var columns: int = 4
@export var h_gap: float = 24.0
@export var v_gap: float = 24.0
@export var top_padding: float = 12.0
@export var bottom_padding: float = 24.0

@export var spring_back_time: float = 0.35
@export var flick_factor: float = 0.12

var _content: Control
var _rows: Array[HBoxContainer] = []
var _tiles: Dictionary = {}          ## level -> LevelTile



var _min_y: float = 0.0              ## most-negative allowed content.position.y
var _tween: Tween

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	resized.connect(_recompute_bounds)

## levels: Array of {level:int, state:LevelTile.State, stars:int}, in display order.
## Returns the created tiles in the same order (handy for staggered pop_in()).
func build(levels: Array) -> Array[LevelTile]:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	_tiles.clear()
	if _tween:
		_tween.kill()
	_content.position = Vector2.ZERO

	var out: Array[LevelTile] = []
	var i := 0
	while i < levels.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(h_gap))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(row)
		_rows.append(row)
		var count: int = mini(columns, levels.size() - i)
		for c in count:
			var entry: Dictionary = levels[i + c]
			var tile := tile_scene.instantiate() as LevelTile
			row.add_child(tile)
			tile.setup(entry["level"], entry["state"], entry.get("stars", 0))
			tile.chosen.connect(func(lvl: int) -> void: tile_chosen.emit(lvl))
			_tiles[entry["level"]] = tile
			out.append(tile)
		i += count

	call_deferred("_layout_rows")
	return out

func tile_for(level: int) -> LevelTile:
	return _tiles.get(level)

## Update one tile in place (e.g. after a "level completed" signal) without rebuilding the grid.
func refresh_tile(level: int, state: LevelTile.State, stars: int = 0) -> void:
	var tile: LevelTile = _tiles.get(level)
	if tile:
		tile.setup(level, state, stars)

# --- layout --------------------------------------------------------------

func _layout_rows() -> void:
	if _rows.is_empty():
		return
	var y := top_padding
	var w := size.x
	for row in _rows:
		row.size.x = w
		row.position = Vector2(0.0, y)
		row.size.y = row.get_combined_minimum_size().y
		y += row.size.y + v_gap
	_content.custom_minimum_size = Vector2(w, y - v_gap + bottom_padding)
	_content.size = _content.custom_minimum_size
	_recompute_bounds()

func _recompute_bounds() -> void:
	_min_y = minf(0.0, size.y - _content.size.y)
	_content.position.y = clampf(_content.position.y, _min_y, 0.0)

# --- input -----------------------------------------------------------------





func _animate_to(target_y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_content, "position:y", target_y, spring_back_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
