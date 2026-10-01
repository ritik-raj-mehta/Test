@tool
extends Control

const LevelDataScript = preload("res://game/scripts/data/LevelData.gd")
const ObjectDataScript = preload("res://game/scripts/data/ObjectData.gd")

signal object_selected(obj_data)
signal object_moved(obj_data)
signal player_start_changed(pos: Vector2)
signal level_data_modified()
signal zoom_changed(new_zoom: float)
signal snapshot_requested()

@export var grid_snap: bool = false
@export var grid_size: int = 32
@export var zoom_scale: float = 1.0

var level_data = null
var selected_object = null
var active_placement_id: String = "" # "" for select mode, "player_start", "tile_brush", "tile_eraser", or object_id

var is_dragging: bool = false
var is_mmb_panning: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var preview_nodes: Dictionary = {} # ObjectData -> Node2D
var player_start_preview: Node2D = null
var canvas_tilemap: TileMapLayer = null

var current_tile_atlas: Vector2i = Vector2i(1, 1)
var hover_cell: Vector2i = Vector2i(-9999, -9999)

# Canvas offset mapping: World (0,0) is at Canvas (100, 2000)
var origin_offset: Vector2 = Vector2(100, 2000)

func _ready() -> void:
	clip_contents = true

func set_level_data(p_data) -> void:
	level_data = p_data
	selected_object = null
	update_origin_offset()
	refresh_canvas()

func update_origin_offset() -> void:
	if level_data:
		origin_offset.y = level_data.level_size.y + 500.0
	else:
		origin_offset.y = 2000.0

func rebuild_objects() -> void:
	refresh_canvas()

func refresh_canvas() -> void:
	update_origin_offset()


	# Clear existing preview nodes
	for child in get_children():
		child.queue_free()
	preview_nodes.clear()
	canvas_tilemap = null

	if not level_data:
		update_canvas_size()
		queue_redraw()
		return

	update_canvas_size()

	var theme_info = WorldThemeRegistry.get_theme(level_data.world_theme)
	var def_atlas: Vector2i = theme_info.get("default_atlas_coords", Vector2i(1, 1))
	var t_size: Vector2i = theme_info.get("tile_size", Vector2i(16, 16))

	# Create TileMapLayer Preview on Canvas
	var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var tile_offset_x: float = fmod(center_x, 48.0)

	canvas_tilemap = TileMapLayer.new()
	canvas_tilemap.name = "CanvasTileMap"
	canvas_tilemap.tile_set = WorldThemeRegistry.create_tileset_for_theme(level_data.world_theme)
	canvas_tilemap.position = (origin_offset + Vector2(tile_offset_x, 0)) * zoom_scale
	var scale_factor: float = 48.0 / float(t_size.x) if t_size.x > 0 else 3.0
	canvas_tilemap.scale = Vector2(scale_factor * zoom_scale, scale_factor * zoom_scale)
	canvas_tilemap.z_index = 0
	add_child(canvas_tilemap)

	# Render saved TileMap cells
	level_data.migrate_tile_data_if_needed()
	var pt_size: int = level_data.packed_tiles.size()
	if pt_size >= 4:
		for i in range(0, pt_size, 4):
			var cell := Vector2i(level_data.packed_tiles[i], level_data.packed_tiles[i + 1])
			var atlas_x: int = level_data.packed_tiles[i + 2]
			var atlas_y: int = level_data.packed_tiles[i + 3]
			canvas_tilemap.set_cell(cell, 0, Vector2i(atlas_x, atlas_y))

	# Create Player Start Marker preview
	var p_start_node := Node2D.new()
	p_start_node.name = "PlayerStartMarker"
	p_start_node.position = world_to_canvas(level_data.player_start)
	p_start_node.scale = Vector2(zoom_scale, zoom_scale)
	p_start_node.z_index = 20

	var p_sprite := Sprite2D.new()
	var p_tex_path := "res://game/assets/sprites/single/Player.png"
	if not ResourceLoader.exists(p_tex_path):
		p_tex_path = WorldThemeRegistry.resolve_texture_path("res://game/assets/sprites/Player.png")
	if ResourceLoader.exists(p_tex_path):
		p_sprite.texture = load(p_tex_path)
		p_sprite.scale = Vector2(0.08, 0.08)
	p_start_node.add_child(p_sprite)

	var p_label := Label.new()
	p_label.text = "PLAYER START"
	p_label.position = Vector2(-50, -60)
	p_start_node.add_child(p_label)

	add_child(p_start_node)
	player_start_preview = p_start_node

	# Create Object Previews (rendered above tiles in editor)
	for obj_data in level_data.objects:
		var node = ObjectRegistry.instantiate_object(obj_data.object_id)
		if node:
			node.position = world_to_canvas(obj_data.position)
			node.rotation_degrees = obj_data.rotation
			node.scale = obj_data.scale * zoom_scale
			node.z_index = 10

			# Apply theme to preview node
			if "world_theme" in node:
				node.set("world_theme", level_data.world_theme)
			if node.has_method("apply_theme"):
				node.call("apply_theme", level_data.world_theme)

			# Apply custom properties to preview node so area_width and area_height update visually on canvas!
			for prop_name in obj_data.properties:
				if prop_name in node:
					node.set(prop_name, obj_data.properties[prop_name])
			if node.has_method("update_shape_size"):
				node.call("update_shape_size")
			if node.has_method("update_components"):
				node.call("update_components")
			if node.has_method("queue_redraw"):
				node.queue_redraw()

			add_child(node)
			preview_nodes[obj_data] = node


	queue_redraw()

func update_canvas_size() -> void:
	update_origin_offset()
	var h: float = 4000.0 * zoom_scale
	var w: float = 1280.0 * zoom_scale
	if level_data:
		h = (level_data.level_size.y + 3000.0) * zoom_scale
		w = max(1280.0 * zoom_scale, (level_data.level_size.x + origin_offset.x * 2.0) * zoom_scale)
	custom_minimum_size = Vector2(w, h)


func world_to_canvas(w_pos: Vector2) -> Vector2:
	return Vector2((w_pos.x + origin_offset.x) * zoom_scale, (w_pos.y + origin_offset.y) * zoom_scale)

func canvas_to_world(c_pos: Vector2) -> Vector2:
	return Vector2((c_pos.x / zoom_scale) - origin_offset.x, (c_pos.y / zoom_scale) - origin_offset.y)

func snap_pos(w_pos: Vector2) -> Vector2:
	if not grid_snap or grid_size <= 0:
		return w_pos
	var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var offset_x: float = fmod(center_x, float(grid_size))
	var sx = snapped(w_pos.x - offset_x, grid_size) + offset_x
	var sy = snapped(w_pos.y, grid_size)
	return Vector2(sx, sy)

func zoom_at_point(zoom_factor: float, pivot_canvas_pos: Vector2, scroll_container: ScrollContainer = null) -> void:
	var old_zoom = zoom_scale
	var new_zoom = clamp(zoom_scale * zoom_factor, 0.25, 4.0)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var pivot_world = Vector2(
		(pivot_canvas_pos.x / old_zoom) - origin_offset.x,
		(pivot_canvas_pos.y / old_zoom) - origin_offset.y
	)

	zoom_scale = new_zoom
	refresh_canvas()
	emit_signal("zoom_changed", zoom_scale)

	if scroll_container:
		var new_pivot_canvas = world_to_canvas(pivot_world)
		var delta_canvas = new_pivot_canvas - pivot_canvas_pos
		scroll_container.scroll_horizontal += int(delta_canvas.x)
		scroll_container.scroll_vertical += int(delta_canvas.y)

func zoom_at_center(zoom_factor: float, scroll_container: ScrollContainer) -> void:
	if not scroll_container:
		return
	var center_c_x = scroll_container.scroll_horizontal + scroll_container.size.x / 2.0
	var center_c_y = scroll_container.scroll_vertical + scroll_container.size.y / 2.0
	zoom_at_point(zoom_factor, Vector2(center_c_x, center_c_y), scroll_container)

func set_zoom_level(target_zoom: float, scroll_container: ScrollContainer) -> void:
	if not scroll_container or is_equal_approx(zoom_scale, target_zoom):
		return
	var factor = target_zoom / zoom_scale
	zoom_at_center(factor, scroll_container)

func place_tile_at(w_pos: Vector2) -> void:
	if not level_data:
		return

	var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var offset_x: float = fmod(center_x, 48.0)

	# 48px tile size (16px * 3.0 scale)
	var cell_x: int = int(floor((w_pos.x - offset_x) / 48.0))
	var cell_y: int = int(floor(w_pos.y / 48.0))

	level_data.migrate_tile_data_if_needed()
	var size: int = level_data.packed_tiles.size()
	var found: bool = false
	for i in range(0, size, 4):
		if level_data.packed_tiles[i] == cell_x and level_data.packed_tiles[i + 1] == cell_y:
			if level_data.packed_tiles[i + 2] != current_tile_atlas.x or level_data.packed_tiles[i + 3] != current_tile_atlas.y:
				level_data.packed_tiles[i + 2] = current_tile_atlas.x
				level_data.packed_tiles[i + 3] = current_tile_atlas.y
				refresh_canvas()
				emit_signal("level_data_modified")
			found = true
			break

	if not found:
		level_data.add_packed_tile(cell_x, cell_y, current_tile_atlas.x, current_tile_atlas.y)
		refresh_canvas()
		emit_signal("level_data_modified")

func erase_tile_at(w_pos: Vector2) -> void:
	if not level_data:
		return
	var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var offset_x: float = fmod(center_x, 48.0)
	var cell_x: int = int(floor((w_pos.x - offset_x) / 48.0))
	var cell_y: int = int(floor(w_pos.y / 48.0))

	level_data.migrate_tile_data_if_needed()
	var size: int = level_data.packed_tiles.size()
	for i in range(size - 4, -1, -4):
		if level_data.packed_tiles[i] == cell_x and level_data.packed_tiles[i + 1] == cell_y:
			level_data.packed_tiles.remove_at(i + 3)
			level_data.packed_tiles.remove_at(i + 2)
			level_data.packed_tiles.remove_at(i + 1)
			level_data.packed_tiles.remove_at(i)
			refresh_canvas()
			emit_signal("level_data_modified")
			return

func _gui_input(event: InputEvent) -> void:
	if not level_data:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var parent_scroll = get_parent() as ScrollContainer
			zoom_at_point(1.15, mb.position, parent_scroll)
			get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var parent_scroll = get_parent() as ScrollContainer
			zoom_at_point(1.0 / 1.15, mb.position, parent_scroll)
			get_viewport().set_input_as_handled()
			return

		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				is_mmb_panning = true
				get_viewport().set_input_as_handled()
				return
			else:
				is_mmb_panning = false
				get_viewport().set_input_as_handled()
				return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var c_pos = mb.position
				var w_pos = canvas_to_world(c_pos)

				if active_placement_id == "tile_brush":
					emit_signal("snapshot_requested")
					place_tile_at(w_pos)
				elif active_placement_id == "tile_eraser":
					emit_signal("snapshot_requested")
					erase_tile_at(w_pos)
				elif active_placement_id == "player_start":
					emit_signal("snapshot_requested")
					level_data.player_start = snap_pos(w_pos)
					if player_start_preview:
						player_start_preview.position = world_to_canvas(level_data.player_start)
					emit_signal("player_start_changed", level_data.player_start)
					emit_signal("level_data_modified")
					queue_redraw()
				elif active_placement_id != "":
					emit_signal("snapshot_requested")
					var new_obj = ObjectDataScript.new(
						active_placement_id,
						snap_pos(w_pos),
						0.0,
						Vector2.ONE,
						ObjectRegistry.get_entry(active_placement_id).get("default_properties", {})
					)
					level_data.add_object(new_obj)
					selected_object = new_obj
					refresh_canvas()
					emit_signal("object_selected", selected_object)
					emit_signal("level_data_modified")
				else:
					# Selection / Move Mode
					var hit_obj = find_object_at_canvas_pos(c_pos)
					if hit_obj:
						emit_signal("snapshot_requested")
						selected_object = hit_obj
						is_dragging = true
						drag_offset = hit_obj.position - w_pos
						emit_signal("object_selected", selected_object)
					else:
						selected_object = null
						is_dragging = false
						emit_signal("object_selected", null)
					queue_redraw()
			else:
				if is_dragging:
					is_dragging = false
					emit_signal("level_data_modified")

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			emit_signal("snapshot_requested")
			var w_pos = canvas_to_world(mb.position)
			erase_tile_at(w_pos)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_mmb_panning or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var parent_scroll = get_parent() as ScrollContainer
			if parent_scroll:
				parent_scroll.scroll_horizontal -= int(mm.relative.x)
				parent_scroll.scroll_vertical -= int(mm.relative.y)
				get_viewport().set_input_as_handled()
				return

		var w_pos = canvas_to_world(mm.position)
		var center_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
		var offset_x: float = fmod(center_x, 48.0)
		hover_cell = Vector2i(int(floor((w_pos.x - offset_x) / 48.0)), int(floor(w_pos.y / 48.0)))

		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if active_placement_id == "tile_brush":
				place_tile_at(w_pos)
			elif active_placement_id == "tile_eraser":
				erase_tile_at(w_pos)
			elif is_dragging and selected_object:
				var target_pos = canvas_to_world(mm.position) + drag_offset
				selected_object.position = snap_pos(target_pos)

				if preview_nodes.has(selected_object):
					preview_nodes[selected_object].position = world_to_canvas(selected_object.position)

				emit_signal("object_moved", selected_object)
		
		queue_redraw()

func find_object_at_canvas_pos(c_pos: Vector2):
	var w_pos = canvas_to_world(c_pos)
	var best_obj = null
	var min_dist: float = 60.0 # hit radius threshold

	for obj in level_data.objects:
		var dist = obj.position.distance_to(w_pos)
		if dist < min_dist:
			min_dist = dist
			best_obj = obj
	return best_obj

func _draw() -> void:
	if not level_data:
		return

	# Draw Playable Boundary Guides (0 to level_size.x in world X)
	var top_c_y = world_to_canvas(Vector2(0, -level_data.level_size.y)).y
	var bot_c_y = world_to_canvas(Vector2(0, 2000)).y
	var left_c_x = world_to_canvas(Vector2(0, 0)).x
	var right_c_x = world_to_canvas(Vector2(level_data.level_size.x, 0)).x

	# Fill playable corridor with subtle theme tint
	var theme_info = WorldThemeRegistry.get_theme(level_data.world_theme)
	var t_color: Color = theme_info.get("theme_color", Color(0.1, 0.1, 0.2, 0.15))
	var fill_color := Color(t_color.r, t_color.g, t_color.b, 0.12)
	draw_rect(Rect2(Vector2(left_c_x, top_c_y), Vector2(level_data.level_size.x * zoom_scale, bot_c_y - top_c_y)), fill_color)

	# Boundary side lines
	draw_line(Vector2(left_c_x, top_c_y), Vector2(left_c_x, bot_c_y), Color(0.2, 0.8, 1.0, 0.8), 3.0 * zoom_scale)
	draw_line(Vector2(right_c_x, top_c_y), Vector2(right_c_x, bot_c_y), Color(0.2, 0.8, 1.0, 0.8), 3.0 * zoom_scale)
	draw_line(Vector2(left_c_x, top_c_y), Vector2(right_c_x, top_c_y), Color(1.0, 0.3, 0.3, 0.8), 3.0 * zoom_scale) # Top Goal boundary
	draw_line(Vector2(left_c_x, bot_c_y), Vector2(right_c_x, bot_c_y), Color(1.0, 0.8, 0.2, 0.8), 3.0 * zoom_scale) # Bottom threshold boundary

	# Center X Axis (540.0)
	var center_w_x: float = level_data.level_size.x / 2.0 if level_data else 540.0
	var center_c_x = world_to_canvas(Vector2(center_w_x, 0)).x

	# Draw Grid Overlay aligned with TileMap & Snap Grid (symmetrically centered around 540)
	var is_tile_tool = (active_placement_id == "tile_brush" or active_placement_id == "tile_eraser")
	if grid_snap or is_tile_tool:
		var tile_step: float = 48.0 if is_tile_tool else float(grid_size)
		var g_color := Color(1.0, 1.0, 1.0, 0.22) if is_tile_tool else Color(1.0, 1.0, 1.0, 0.09)
		var offset_x: float = fmod(center_w_x, tile_step)

		var min_cx = int(floor((-200.0 - offset_x) / tile_step))
		var max_cx = int(ceil((level_data.level_size.x + 200.0 - offset_x) / tile_step))
		for cx in range(min_cx, max_cx + 1):
			var line_w_x = float(cx) * tile_step + offset_x
			var line_c_x = world_to_canvas(Vector2(line_w_x, 0)).x
			draw_line(Vector2(line_c_x, top_c_y), Vector2(line_c_x, bot_c_y), g_color, 1.0)

		var min_cy = int(floor(-level_data.level_size.y / tile_step)) - 1
		var max_cy = int(ceil(2000.0 / tile_step)) + 1
		for cy in range(min_cy, max_cy + 1):
			var line_c_y = world_to_canvas(Vector2(0, float(cy) * tile_step)).y
			draw_line(Vector2(left_c_x, line_c_y), Vector2(right_c_x, line_c_y), g_color, 1.0)

	# Draw prominent Center Axis Line (X = 540)
	draw_line(Vector2(center_c_x, top_c_y), Vector2(center_c_x, bot_c_y), Color(1.0, 0.85, 0.2, 0.85), 2.0 * zoom_scale)

	# Draw Game Screen Viewport Indicator Area (1080 x 1920 centered on player start)
	var screen_w: float = 1080.0
	var screen_h: float = 1920.0
	var player_pos: Vector2 = level_data.player_start
	var cam_top_w_y = player_pos.y - 1300.0
	var screen_top_left_w = Vector2(player_pos.x - (screen_w / 2.0), cam_top_w_y)
	var screen_top_left_c = world_to_canvas(screen_top_left_w)
	var screen_c_size = Vector2(screen_w * zoom_scale, screen_h * zoom_scale)
	var screen_rect := Rect2(screen_top_left_c, screen_c_size)

	draw_rect(screen_rect, Color(0.2, 0.85, 1.0, 0.05))
	draw_rect(screen_rect, Color(0.2, 0.85, 1.0, 0.9), false, 2.5 * zoom_scale)

	# Draw Tile Brush / Eraser Mouse Cursor Grid Box Highlight
	if is_tile_tool and hover_cell != Vector2i(-9999, -9999):
		var offset_x: float = fmod(center_w_x, 48.0)
		var cell_w_pos = Vector2(hover_cell.x * 48.0 + offset_x, hover_cell.y * 48.0)
		var cell_c_pos = world_to_canvas(cell_w_pos)
		var cell_rect := Rect2(cell_c_pos, Vector2(48.0 * zoom_scale, 48.0 * zoom_scale))

		if active_placement_id == "tile_brush":
			draw_rect(cell_rect, Color(0.2, 1.0, 0.5, 0.35))
			draw_rect(cell_rect, Color(0.2, 1.0, 0.5, 0.9), false, 2.0)
		elif active_placement_id == "tile_eraser":
			draw_rect(cell_rect, Color(1.0, 0.3, 0.3, 0.35))
			draw_rect(cell_rect, Color(1.0, 0.3, 0.3, 0.9), false, 2.0)

	# Draw Selection Outline around selected object
	if selected_object and preview_nodes.has(selected_object):
		var node = preview_nodes[selected_object]
		var n_pos = node.position
		var box_size = Vector2(120, 120) * selected_object.scale * zoom_scale
		var rect := Rect2(n_pos - box_size / 2.0, box_size)
		draw_rect(rect, Color(1.0, 0.9, 0.1, 0.9), false, 2.5)

	# Draw X & Y Coordinate Scale / Rulers
	draw_canvas_rulers(left_c_x, right_c_x, top_c_y, bot_c_y)

	# Screen View Labels
	var font = ThemeDB.fallback_font
	if font:
		var label_pos = screen_top_left_c + Vector2(15 * zoom_scale, 28 * zoom_scale)
		draw_string(font, label_pos, "📱 GAME SCREEN VIEW (1080 x 1920)", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * zoom_scale), Color(0.2, 0.9, 1.0, 1.0))
		var center_label_pos = Vector2(center_c_x + 8 * zoom_scale, top_c_y + 40 * zoom_scale)
		draw_string(font, center_label_pos, "CENTER (540)", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * zoom_scale), Color(1.0, 0.85, 0.2, 1.0))

func draw_canvas_rulers(left_c_x: float, right_c_x: float, top_c_y: float, bot_c_y: float) -> void:
	if not level_data:
		return

	var font = ThemeDB.fallback_font
	var font_size = int(clamp(11 * zoom_scale, 9, 14))
	var ruler_color = Color(0.9, 0.95, 1.0, 0.85)
	var tick_color = Color(0.2, 0.8, 1.0, 0.7)

	# 1. X-Axis Scale Labels & Ticks (along Top & Bottom boundaries)
	var x_step: float = 100.0
	if zoom_scale < 0.6:
		x_step = 200.0

	var cur_wx: float = 0.0
	while cur_wx <= level_data.level_size.x:
		var c_x = world_to_canvas(Vector2(cur_wx, 0)).x

		draw_line(Vector2(c_x, top_c_y), Vector2(c_x, top_c_y - 12 * zoom_scale), tick_color, 1.5)
		draw_line(Vector2(c_x, bot_c_y), Vector2(c_x, bot_c_y + 12 * zoom_scale), tick_color, 1.5)

		var label_str = str(int(cur_wx))
		if font:
			draw_string(font, Vector2(c_x - 20, top_c_y - 15 * zoom_scale), label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, ruler_color)
			draw_string(font, Vector2(c_x - 20, bot_c_y + 25 * zoom_scale), label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, ruler_color)

		cur_wx += x_step

	# 2. Y-Axis Scale Labels & Ticks (along Left & Right boundaries)
	var y_step: float = 200.0
	if zoom_scale < 0.6:
		y_step = 400.0

	var min_wy: float = -level_data.level_size.y
	var max_wy: float = 2000.0

	var cur_wy: float = min_wy
	while cur_wy <= max_wy:
		var c_y = world_to_canvas(Vector2(0, cur_wy)).y

		draw_line(Vector2(left_c_x, c_y), Vector2(left_c_x - 12 * zoom_scale, c_y), tick_color, 1.5)
		draw_line(Vector2(right_c_x, c_y), Vector2(right_c_x + 12 * zoom_scale, c_y), tick_color, 1.5)

		var label_str = str(int(cur_wy))
		if font:
			draw_string(font, Vector2(left_c_x - 55 * zoom_scale, c_y + 4), label_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, ruler_color)
			draw_string(font, Vector2(right_c_x + 16 * zoom_scale, c_y + 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ruler_color)

		cur_wy += y_step

	# 3. Real-time Cursor Coordinates Tooltip HUD
	if hover_cell != Vector2i(-9999, -9999):
		var w_mouse = canvas_to_world(get_local_mouse_position())
		var hud_text = " X: %d  Y: %d " % [int(w_mouse.x), int(w_mouse.y)]
		if font:
			var box_pos = get_local_mouse_position() + Vector2(18, 18)
			draw_rect(Rect2(box_pos, Vector2(115, 24)), Color(0.05, 0.05, 0.1, 0.85), true)
			draw_rect(Rect2(box_pos, Vector2(115, 24)), Color(0.2, 0.8, 1.0, 0.9), false, 1.2)
			draw_string(font, box_pos + Vector2(8, 17), hud_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 1))
