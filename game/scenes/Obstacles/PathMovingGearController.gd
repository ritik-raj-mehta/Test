@tool
extends Node2D
class_name PathMovingGearController

enum PathShape {
	CIRCLE = 0,
	RECTANGLE = 1,
	SQUARE = 2,
	TRIANGLE = 3,
	DIAMOND = 4
}

enum MoveDirection {
	CLOCKWISE = 0,
	COUNTER_CLOCKWISE = 1,
	ALTERNATING = 2
}

@export_enum("Circle", "Rectangle", "Square", "Triangle", "Diamond") var path_shape: String = "Diamond":
	set(v):
		path_shape = v
		_update_path_geometry()
		_update_caches()
		queue_redraw()

@export var path_width: float = 300.0:
	set(v):
		path_width = max(10.0, v)
		_update_path_geometry()
		_update_caches()
		queue_redraw()

@export var path_height: float = 300.0:
	set(v):
		path_height = max(10.0, v)
		_update_path_geometry()
		_update_caches()
		queue_redraw()

@export var path_rotation: float = 0.0: # degrees
	set(v):
		path_rotation = v
		_update_path_geometry()
		_update_caches()
		queue_redraw()

@export_enum("Clockwise", "Counter-Clockwise", "Alternating") var move_direction: String = "Clockwise":
	set(v):
		move_direction = v
		_update_caches()
		queue_redraw()

@export var alternate_interval: float = 0.0: # Time in seconds before reversing if Alternating (0 = reverse per full loop)
	set(v):
		alternate_interval = max(0.0, v)
		_update_caches()

@export var corner_delay: float = 0.0: # Pause duration in seconds at each corner vertex
	set(v):
		corner_delay = max(0.0, v)
		_update_caches()
		queue_redraw()

@export var move_speed: float = 150.0:
	set(v):
		move_speed = max(0.0, v)
		_update_caches()

@export_group("Interval Movement & Speed Curve")
@export var enable_interval_movement: bool = false:
	set(v):
		enable_interval_movement = v
		_update_caches()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_time: float = 3.0: # Time duration in seconds per interval movement cycle
	set(v):
		interval_time = max(0.1, v)
		_update_caches()

@export var interval_speed: float = 150.0: # Fixed movement speed during interval
	set(v):
		interval_speed = v
		_update_caches()

@export var enable_speed_modulation: bool = false: # Smooth speed wave: start move -> slow down -> speed up -> slow down
	set(v):
		enable_speed_modulation = v
		_update_caches()

@export var min_speed_scale: float = 0.25: # Minimum speed multiplier during slow phase
	set(v):
		min_speed_scale = clampf(v, 0.0, 3.0)
		_update_caches()

@export var max_speed_scale: float = 1.75: # Peak speed multiplier during fast phase
	set(v):
		max_speed_scale = max(0.1, v)
		_update_caches()

@export var speed_pulses_per_interval: float = 2.0: # Number of speed-up/slow-down pulses per interval
	set(v):
		speed_pulses_per_interval = max(0.5, v)
		_update_caches()

@export var rotation_speed: float = 2.0:
	set(v):
		rotation_speed = v

@export_range(1, 10, 1) var gear_count: int = 2:
	set(v):
		gear_count = clampi(v, 1, 10)
		_rebuild_gears()
		_update_caches()
		queue_redraw()

@export var show_track_line: bool = true:
	set(v):
		show_track_line = v
		queue_redraw()

@export var track_color: Color = Color(0.35, 0.35, 0.35, 0.7):
	set(v):
		track_color = v
		queue_redraw()

@export var track_width: float = 2.5:
	set(v):
		track_width = max(1.0, v)
		queue_redraw()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

@onready var gear_body: StaticBody2D = $GearBody if has_node("GearBody") else null
@onready var gear_sprite: Sprite2D = $GearBody/Sprite2D if has_node("GearBody/Sprite2D") else null

# Precomputed geometry caches
var _vertices: PackedVector2Array = PackedVector2Array()
var _segment_lengths: PackedFloat32Array = PackedFloat32Array()
var _cumulative_lengths: PackedFloat32Array = PackedFloat32Array()
var _total_perimeter: float = 0.0
var _is_circular: bool = false
var _cycle_duration: float = 0.0
var _elapsed_time: float = 0.0
var _current_dir_sign: float = 1.0

# Gear body pool
var _gear_bodies: Array[StaticBody2D] = []
var _gear_sprites: Array[Sprite2D] = []

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	_rebuild_gears()
	_update_path_geometry()
	_update_caches()
	_apply_theme()

func update_components() -> void:
	_rebuild_gears()
	_update_path_geometry()
	_update_caches()
	_apply_theme()

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

func _apply_theme() -> void:
	if gear_sprite == null and has_node("GearBody/Sprite2D"):
		gear_sprite = get_node("GearBody/Sprite2D") as Sprite2D

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	var g_tex = WorldThemeRegistry.get_gear_texture(theme_id)
	if g_tex:
		for spr in _gear_sprites:
			if spr:
				spr.texture = g_tex

func _rebuild_gears() -> void:
	if gear_body == null and has_node("GearBody"):
		gear_body = get_node("GearBody") as StaticBody2D
	if gear_sprite == null and has_node("GearBody/Sprite2D"):
		gear_sprite = get_node("GearBody/Sprite2D") as Sprite2D

	_gear_bodies.clear()
	_gear_sprites.clear()

	if gear_body:
		_gear_bodies.append(gear_body)
		if gear_sprite:
			_gear_sprites.append(gear_sprite)

	# Clean up previous clone children (including internal ones)
	for child in get_children(true):
		if child != gear_body and (child.name.begins_with("PathGear_Clone_") or child.is_in_group("gear_clone")):
			child.queue_free()
			remove_child(child)

	var target_count = max(1, gear_count)
	for i in range(1, target_count):
		if gear_body:
			var clone = gear_body.duplicate() as StaticBody2D
			clone.name = "PathGear_Clone_%d" % i
			clone.add_to_group("gear_clone")
			# Use INTERNAL_MODE_BACK so clones are never serialized to .tscn and don't dirty the editor scene
			add_child(clone, false, Node.INTERNAL_MODE_BACK)
			_gear_bodies.append(clone)
			var spr = clone.get_node_or_null("Sprite2D") as Sprite2D
			if spr:
				_gear_sprites.append(spr)

func _update_path_geometry() -> void:
	_vertices.clear()
	_segment_lengths.clear()
	_cumulative_lengths.clear()
	_total_perimeter = 0.0

	var norm_shape = path_shape.to_upper()
	_is_circular = (norm_shape == "CIRCLE")

	var half_w = path_width * 0.5
	var half_h = path_height * 0.5
	var rad_offset = deg_to_rad(path_rotation)

	var raw_points: Array[Vector2] = []

	match norm_shape:
		"CIRCLE":
			_total_perimeter = PI * (3.0 * (half_w + half_h) - sqrt((3.0 * half_w + half_h) * (half_w + 3.0 * half_h)))
			if _total_perimeter <= 0.0:
				_total_perimeter = max(1.0, TAU * half_w)
			return

		"DIAMOND":
			raw_points = [
				Vector2(0.0, -half_h),
				Vector2(half_w, 0.0),
				Vector2(0.0, half_h),
				Vector2(-half_w, 0.0)
			]

		"SQUARE":
			var sz = max(half_w, half_h)
			raw_points = [
				Vector2(-sz, -sz),
				Vector2(sz, -sz),
				Vector2(sz, sz),
				Vector2(-sz, sz)
			]

		"TRIANGLE":
			raw_points = [
				Vector2(0.0, -half_h),
				Vector2(half_w, half_h),
				Vector2(-half_w, half_h)
			]

		"RECTANGLE", _:
			raw_points = [
				Vector2(-half_w, -half_h),
				Vector2(half_w, -half_h),
				Vector2(half_w, half_h),
				Vector2(-half_w, half_h)
			]

	var n = raw_points.size()
	for i in range(n):
		var p = raw_points[i].rotated(rad_offset)
		_vertices.append(p)

	var accum: float = 0.0
	for i in range(n):
		var p1 = _vertices[i]
		var p2 = _vertices[(i + 1) % n]
		var seg_len = p1.distance_to(p2)
		_segment_lengths.append(seg_len)
		accum += seg_len
		_cumulative_lengths.append(accum)

	_total_perimeter = accum

func _update_caches() -> void:
	var n_corners = _vertices.size() if not _is_circular else 0
	var travel_time = _total_perimeter / max(1.0, move_speed)
	_cycle_duration = travel_time + float(n_corners) * corner_delay
	_update_gears_positions(0.0)

func _get_effective_speed(t_active: float) -> float:
	var base_spd = interval_speed if enable_interval_movement else move_speed
	if not enable_speed_modulation:
		return base_spd
	var duration = interval_time if (enable_interval_movement and interval_time > 0.0) else max(0.5, _cycle_duration)
	var phase = (t_active / max(0.1, duration)) * speed_pulses_per_interval * TAU
	var wave = 0.5 * (1.0 + sin(phase))
	return base_spd * lerpf(min_speed_scale, max_speed_scale, wave)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var cur_spd = _get_effective_speed(_elapsed_time)

	# Rotate all gear sprites
	if rotation_speed != 0.0:
		var base_ref = interval_speed if enable_interval_movement else move_speed
		var spin_scale = (cur_spd / max(1.0, base_ref)) if base_ref > 0.0 else 1.0
		for spr in _gear_sprites:
			if spr:
				spr.rotation += rotation_speed * spin_scale * delta

	if cur_spd <= 0.0 or _total_perimeter <= 0.0:
		return

	# Effective movement time progression scaled by cur_spd
	var base_spd = interval_speed if enable_interval_movement else move_speed
	var speed_ratio = cur_spd / max(1.0, base_spd)
	_elapsed_time += delta * speed_ratio

	# Handle Direction
	var norm_dir = move_direction.to_upper()
	match norm_dir:
		"COUNTER-CLOCKWISE", "COUNTER_CLOCKWISE":
			_current_dir_sign = -1.0
		"ALTERNATING":
			var period = alternate_interval if alternate_interval > 0.0 else max(1.0, _cycle_duration)
			var phase = int(_elapsed_time / period)
			_current_dir_sign = 1.0 if (phase % 2 == 0) else -1.0
		_: # Clockwise
			_current_dir_sign = 1.0

	_update_gears_positions(_elapsed_time)

func _update_gears_positions(t_current: float) -> void:
	var count = _gear_bodies.size()
	if count == 0:
		return

	for i in range(count):
		var body = _gear_bodies[i]
		if not body:
			continue

		# Distribute gears evenly around the loop
		var gear_offset_time = float(i) * (_cycle_duration / float(count))
		var effective_t: float = 0.0

		if _current_dir_sign >= 0.0:
			effective_t = fposmod(t_current + gear_offset_time, max(0.0001, _cycle_duration))
		else:
			effective_t = fposmod((_cycle_duration - fposmod(t_current, _cycle_duration)) + gear_offset_time, max(0.0001, _cycle_duration))

		body.position = _sample_path_position(effective_t)

func _sample_path_position(t: float) -> Vector2:
	if _is_circular:
		var travel_time = _cycle_duration
		var progress = fposmod(t / max(0.0001, travel_time), 1.0)
		var angle = progress * TAU + deg_to_rad(path_rotation)
		var half_w = path_width * 0.5
		var half_h = path_height * 0.5
		return Vector2(cos(angle) * half_w, sin(angle) * half_h)

	var n = _vertices.size()
	if n == 0:
		return Vector2.ZERO

	if corner_delay <= 0.0:
		var dist_progress = fposmod((t * move_speed), _total_perimeter)
		return _sample_polygon_distance(dist_progress)

	# Traversal with corner delays
	var seg_count = n
	var move_time_per_seg = (_total_perimeter / float(seg_count)) / max(1.0, move_speed)
	var seg_cycle = move_time_per_seg + corner_delay

	var current_seg_idx = int(t / seg_cycle) % seg_count
	var seg_t = fmod(t, seg_cycle)

	var p_start = _vertices[current_seg_idx]
	var p_end = _vertices[(current_seg_idx + 1) % seg_count]

	if seg_t < move_time_per_seg:
		var ratio = seg_t / move_time_per_seg
		return p_start.lerp(p_end, ratio)
	else:
		# Paused at corner endpoint
		return p_end

func _sample_polygon_distance(dist: float) -> Vector2:
	var n = _vertices.size()
	var prev_accum: float = 0.0
	for i in range(n):
		var seg_len = _segment_lengths[i]
		if dist <= prev_accum + seg_len or i == n - 1:
			var seg_dist = dist - prev_accum
			var ratio = clampf(seg_dist / max(0.001, seg_len), 0.0, 1.0)
			return _vertices[i].lerp(_vertices[(i + 1) % n], ratio)
		prev_accum += seg_len
	return _vertices[0]

func reset() -> void:
	# Keep current gear movement phase & position intact on player death/respawn
	pass

func is_in_editor() -> bool:
	if Engine.is_editor_hint():
		return true
	var n: Node = self
	while n:
		if n.name == "LevelEditor" or n.name == "LevelCanvas" or n.has_method("new_level") or n.is_in_group("level_editor"):
			return true
		n = n.get_parent()
	return false

func _draw() -> void:
	var in_ed = is_in_editor()
	if not show_track_line and not in_ed:
		return

	var draw_col = track_color
	if in_ed:
		draw_col = Color(0.1, 0.85, 1.0, 0.85) # Vibrant cyan guideline in editor

	if _is_circular:
		var half_w = path_width * 0.5
		var half_h = path_height * 0.5
		var pts: PackedVector2Array = PackedVector2Array()
		var steps = 48
		var rad_offset = deg_to_rad(path_rotation)
		for s in range(steps + 1):
			var a = (float(s) / float(steps)) * TAU + rad_offset
			pts.append(Vector2(cos(a) * half_w, sin(a) * half_h))
		draw_polyline(pts, draw_col, track_width, true)

		# Draw direction arrows in editor
		if in_ed:
			for k in range(4):
				var ang = (float(k) / 4.0) * TAU + rad_offset
				var pt = Vector2(cos(ang) * half_w, sin(ang) * half_h)
				var tangent = Vector2(-sin(ang) * half_w, cos(ang) * half_h).normalized()
				_draw_arrow_head(pt, tangent * 10.0, Color(1.0, 0.85, 0.2, 0.9))
	else:
		var n = _vertices.size()
		if n >= 2:
			var pts = _vertices.duplicate()
			pts.append(_vertices[0])
			draw_polyline(pts, draw_col, track_width, true)

			if in_ed:
				for i in range(n):
					var p1 = _vertices[i]
					var p2 = _vertices[(i + 1) % n]
					var mid = (p1 + p2) * 0.5
					var dir = (p2 - p1).normalized()
					# Draw direction arrow in middle of edge
					_draw_arrow_head(mid, dir * 12.0, Color(1.0, 0.85, 0.2, 0.9))
					# Draw corner vertex marker
					draw_circle(p1, 4.0, Color(1.0, 0.35, 0.35, 0.9))

	if in_ed:
		# Draw center origin marker
		draw_circle(Vector2.ZERO, 5.0, Color(0.2, 1.0, 0.4, 0.95))

		var font = ThemeDB.fallback_font
		if font:
			var info = "%s (%.0fx%.0f) | %d Gears | %s" % [path_shape, path_width, path_height, gear_count, move_direction]
			if corner_delay > 0.0:
				info += " | Delay: %.1fs" % corner_delay
			draw_string(font, Vector2(-path_width * 0.5, path_height * 0.5 + 20.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))

func _draw_arrow_head(tip: Vector2, dir_vec: Vector2, color: Color) -> void:
	var perp = dir_vec.orthogonal() * 0.5
	draw_line(tip, tip - dir_vec + perp, color, 2.0)
	draw_line(tip, tip - dir_vec - perp, color, 2.0)
