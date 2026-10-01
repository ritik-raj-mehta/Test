@tool
class_name AtlasPalettePicker
extends Control

signal tile_selected(coords: Vector2i)
signal multi_tiles_selected(tiles: Array[Vector2i])
signal zoom_changed(new_zoom: float)

@export var tile_size: Vector2i = Vector2i(16, 16)

@export var zoom_scale: float = 2.0:
	set(val):
		zoom_scale = clamp(val, 0.5, 6.0)
		_update_picker_size()
		queue_redraw()
		emit_signal("zoom_changed", zoom_scale)

var texture: Texture2D = null:
	set(val):
		texture = val
		_update_picker_size()
		queue_redraw()

var selected_coords: Vector2i = Vector2i(1, 1):
	set(val):
		selected_coords = val
		if not selected_tiles.has(val):
			selected_tiles = [val]
		queue_redraw()

var selected_tiles: Array[Vector2i] = [Vector2i(1, 1)]:
	set(val):
		selected_tiles = val
		queue_redraw()

var hover_coords: Vector2i = Vector2i(-1, -1):
	set(val):
		if hover_coords != val:
			hover_coords = val
			queue_redraw()

var is_dragging_palette: bool = false
var palette_drag_start: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	clip_contents = true
	mouse_exited.connect(func(): hover_coords = Vector2i(-1, -1))
	_update_picker_size()

func _get_cols() -> int:
	if not texture or tile_size.x <= 0:
		return 1
	return max(1, int(texture.get_width() / tile_size.x))

func _get_rows() -> int:
	if not texture or tile_size.y <= 0:
		return 1
	return max(1, int(texture.get_height() / tile_size.y))

func get_cell_size() -> float:
	return tile_size.x * zoom_scale

func _update_picker_size() -> void:
	if not texture:
		custom_minimum_size = Vector2(230, 120)
		return
	var cols = _get_cols()
	var rows = _get_rows()
	var cell_w = get_cell_size()
	var total_w = cols * cell_w
	var total_h = rows * cell_w
	custom_minimum_size = Vector2(total_w, total_h)

func ensure_selected_visible(scroll_container: ScrollContainer) -> void:
	if not scroll_container or not texture:
		return
	var cell_w = get_cell_size()
	var target_x = selected_coords.x * cell_w
	var target_y = selected_coords.y * cell_w
	
	if target_x < scroll_container.scroll_horizontal or target_x + cell_w > scroll_container.scroll_horizontal + scroll_container.size.x:
		scroll_container.scroll_horizontal = int(target_x - scroll_container.size.x / 2.0 + cell_w / 2.0)
	if target_y < scroll_container.scroll_vertical or target_y + cell_w > scroll_container.scroll_vertical + scroll_container.size.y:
		scroll_container.scroll_vertical = int(target_y - scroll_container.size.y / 2.0 + cell_w / 2.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var cols = _get_cols()
	var rows = _get_rows()
	var cell_w = get_cell_size()
	var draw_width = cols * cell_w
	var draw_height = rows * cell_w

	# 1. Draw background panel
	draw_rect(Rect2(0, 0, draw_width, draw_height), Color(0.1, 0.1, 0.12, 1.0), true)

	if not texture:
		draw_string(ThemeDB.fallback_font, Vector2(10, 30), "No Tile Map Image", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GRAY)
		return

	# 2. Draw full atlas sheet texture
	draw_texture_rect(texture, Rect2(0, 0, draw_width, draw_height), false)

	# 3. Draw grid lines between tiles
	var grid_color := Color(1.0, 1.0, 1.0, 0.25)
	for c in range(cols + 1):
		var x = c * cell_w
		draw_line(Vector2(x, 0), Vector2(x, draw_height), grid_color, 1.0)
	for r in range(rows + 1):
		var y = r * cell_w
		draw_line(Vector2(0, y), Vector2(draw_width, y), grid_color, 1.0)

	# 4. Draw hover indicator
	if hover_coords.x >= 0 and hover_coords.x < cols and hover_coords.y >= 0 and hover_coords.y < rows:
		var hover_rect := Rect2(hover_coords.x * cell_w, hover_coords.y * cell_w, cell_w, cell_w)
		draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.25), true)
		draw_rect(hover_rect, Color(1.0, 1.0, 1.0, 0.7), false, 1.5)

	# 5. Draw selection box around all selected tiles
	for t in selected_tiles:
		if t.x >= 0 and t.x < cols and t.y >= 0 and t.y < rows:
			var is_primary = (t == selected_coords)
			var sel_rect := Rect2(t.x * cell_w, t.y * cell_w, cell_w, cell_w)
			var fill_col = Color(1.0, 0.85, 0.0, 0.35) if is_primary else Color(0.2, 0.8, 1.0, 0.3)
			var border_col = Color(1.0, 0.9, 0.0, 1.0) if is_primary else Color(0.2, 0.9, 1.0, 0.85)
			draw_rect(sel_rect, fill_col, true)
			draw_rect(sel_rect, border_col, false, 2.5 if is_primary else 1.8)

@export var multi_select_mode: bool = false:
	set(val):
		multi_select_mode = val
		queue_redraw()

func clear_tile_selection() -> void:
	selected_tiles = [selected_coords]
	queue_redraw()
	emit_signal("multi_tiles_selected", selected_tiles)

func _gui_input(event: InputEvent) -> void:
	if not texture:
		return

	var cols = _get_cols()
	var rows = _get_rows()
	var cell_w = get_cell_size()

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var col = clamp(int(mm.position.x / cell_w), 0, cols - 1)
		var row = clamp(int(mm.position.y / cell_w), 0, rows - 1)
		hover_coords = Vector2i(col, row)

		if is_dragging_palette and palette_drag_start != Vector2i(-1, -1):
			var min_cx = mini(palette_drag_start.x, col)
			var max_cx = maxi(palette_drag_start.x, col)
			var min_cy = mini(palette_drag_start.y, row)
			var max_cy = maxi(palette_drag_start.y, row)
			var new_tiles: Array[Vector2i] = selected_tiles.duplicate() if multi_select_mode else []
			for cy in range(min_cy, max_cy + 1):
				for cx in range(min_cx, max_cx + 1):
					var tile := Vector2i(cx, cy)
					if not new_tiles.has(tile):
						new_tiles.append(tile)
			selected_tiles = new_tiles
			queue_redraw()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var col = clamp(int(mb.position.x / cell_w), 0, cols - 1)
			var row = clamp(int(mb.position.y / cell_w), 0, rows - 1)
			var clicked_tile = Vector2i(col, row)

			if mb.pressed:
				if multi_select_mode or mb.shift_pressed or mb.ctrl_pressed:
					# Multi-select toggle mode
					if selected_tiles.has(clicked_tile) and selected_tiles.size() > 1:
						selected_tiles.erase(clicked_tile)
						if selected_coords == clicked_tile and not selected_tiles.is_empty():
							selected_coords = selected_tiles[0]
					else:
						if not selected_tiles.has(clicked_tile):
							selected_tiles.append(clicked_tile)
						selected_coords = clicked_tile
					queue_redraw()
					emit_signal("tile_selected", selected_coords)
					emit_signal("multi_tiles_selected", selected_tiles)
				else:
					# Normal single select & begin possible drag box
					is_dragging_palette = true
					palette_drag_start = clicked_tile
					selected_coords = clicked_tile
					selected_tiles = [clicked_tile]
					queue_redraw()
					emit_signal("tile_selected", selected_coords)
					emit_signal("multi_tiles_selected", selected_tiles)
			else:
				if is_dragging_palette:
					is_dragging_palette = false
					palette_drag_start = Vector2i(-1, -1)
					emit_signal("tile_selected", selected_coords)
					emit_signal("multi_tiles_selected", selected_tiles)

		elif mb.ctrl_pressed and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_scale += 0.25
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_scale -= 0.25
				accept_event()
