class_name BackdropManager
extends CanvasLayer

## Blurred popup background, owned centrally. Popups only set `uses_backdrop = true`.
## Textures come from one BackdropSet resource (atlas regions picked in the inspector).

const SET_PATH: String = "res://game/assets/data/blur_bg_data.tres"

var _logger: Node
var _bus: Node
var _save: SaveManager
var _ui: UIManager

var _set: BackdropSet
var _rect: TextureRect
var _focus_world: int = -1    # set by Worlds popup while swiping; -1 = current level's world


func configure(logger: Node, bus: Node, save: SaveManager, ui: UIManager) -> void:
	_logger = logger
	_bus = bus
	_save = save
	_ui = ui


func _ready() -> void:
	layer = 99  # just under UIManager (100)
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists(SET_PATH):
		_set = load(SET_PATH) as BackdropSet
	if _set == null:
		push_error("BackdropManager: missing BackdropSet at " + SET_PATH)

	_rect = TextureRect.new()
	_rect.name = "Backdrop"
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)
	# _rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	if _bus:
		_bus.screen_opened.connect(_on_screen_opened)
		_bus.screen_closed.connect(_on_screen_closed)
		_bus.world_focused.connect(_on_world_focused)


func _on_screen_opened(_screen_name: String) -> void:
	_refresh()


func _on_screen_closed(_screen_name: String) -> void:
	_focus_world = -1
	_refresh()


func _on_world_focused(world_index: int) -> void:
	_focus_world = world_index
	_refresh()


func _refresh() -> void:
	var top: Control = _ui.current() if _ui else null
	if top == null or _set == null or not bool(top.get("uses_backdrop")):
		_rect.visible = false
		return

	var world := _focus_world if _focus_world >= 0 else _current_world()
	_rect.texture = _set.texture_for(world)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# _rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# _rect.stretch_mode = TextureRect.STRETCH_SCALE
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_rect.size = Vector2(viewport_size.x + 50, viewport_size.y + 100)  # Add some padding
	if _rect.texture == null and _logger:
		_logger.warn("BackdropManager: no backdrop for world index %d" % world)
	_rect.visible = _rect.texture != null


func _current_world() -> int:
	return WorldCatalog.world_index_for_level(_save.get_level() if _save else 1)
