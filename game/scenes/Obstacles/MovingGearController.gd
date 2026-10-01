@tool
extends ObstacleController
class_name MovingGearController

@export var rotation_speed: float = 2.0:
	set(v):
		rotation_speed = v
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_speed: float = 100.0:
	set(v):
		move_speed = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_dist_pos: float = 200.0:
	set(v):
		move_dist_pos = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_dist_neg: float = 200.0:
	set(v):
		move_dist_neg = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_angle: float = 0.0: # degrees: 0 = Horizontal (+X / -X), 90 = Vertical (+Y / -Y), or any custom angle
	set(v):
		move_angle = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var start_delay: float = 0.0: # Initial delay in seconds before movement starts
	set(v):
		start_delay = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var direction_change_delay: float = 0.0: # Delay in seconds at each end before reversing direction
	set(v):
		direction_change_delay = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var delay: float = 0.0: # Alias for direction_change_delay
	set(v):
		delay = v
		direction_change_delay = max(0.0, v)

@export var gear_count: int = 1: # Number of moving gears
	set(v):
		gear_count = clampi(v, 1, 20)
		_rebuild_gears()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(0.0, 5000.0, 1.0, "or_greater") var gear_spacing: float = 100.0: # Distance between each gear
	set(v):
		gear_spacing = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

# Backward compatibility properties
@export var move_distance: float = 200.0:
	set(v):
		move_distance = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_enum("X", "+X", "-X", "Y", "+Y", "-Y", "CUSTOM") var move_direction: String = "X":
	set(v):
		move_direction = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

var start_pos: Vector2
@onready var sprite_gear: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

# Precomputed O(1) physics caches and internal clone pool
var _move_dir_vec: Vector2 = Vector2.RIGHT
var _center_offset: float = 0.0
var _amplitude: float = 0.0
var _has_movement: bool = false
var _travel_time: float = 0.0
var _cycle_duration: float = 0.0
var _elapsed_time: float = 0.0

var _gear_bodies: Array[CollisionObject2D] = []
var _gear_sprites: Array[Sprite2D] = []

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	super._ready()
	start_pos = position
	_rebuild_gears()
	_update_movement_cache()
	_apply_theme()

func update_components() -> void:
	start_pos = position
	_rebuild_gears()
	_update_movement_cache()
	_apply_theme()

func _rebuild_gears() -> void:
	if sprite_gear == null and has_node("Sprite2D"):
		sprite_gear = get_node("Sprite2D") as Sprite2D
	if col_shape == null and has_node("CollisionShape2D"):
		col_shape = get_node("CollisionShape2D") as CollisionShape2D

	_gear_bodies.clear()
	_gear_sprites.clear()

	_gear_bodies.append(self)
	if sprite_gear:
		_gear_sprites.append(sprite_gear)

	# Clean up any existing clone children (including internal ones)
	for child in get_children(true):
		if child != self and (child.name.begins_with("MovingGear_Clone_") or child.is_in_group("gear_clone")):
			child.queue_free()
			remove_child(child)

	var target_count = max(1, gear_count)
	for i in range(1, target_count):
		var clone := StaticBody2D.new()
		clone.name = "MovingGear_Clone_%d" % i
		clone.add_to_group("obstacle")
		clone.add_to_group("gear_clone")
		clone.collision_layer = collision_layer
		clone.collision_mask = collision_mask

		if col_shape and col_shape.shape:
			var clone_col := CollisionShape2D.new()
			clone_col.shape = col_shape.shape
			clone.add_child(clone_col)

		var clone_spr := Sprite2D.new()
		clone_spr.z_index = 2
		clone_spr.scale = Vector2(0.5, 0.5)
		if sprite_gear and sprite_gear.texture:
			clone_spr.texture = sprite_gear.texture
		clone.add_child(clone_spr)

		# Position clone with spacing offset along track relative to root
		clone.position = _move_dir_vec * (float(i) * gear_spacing)

		# Add as internal back child so it never dirties the scene or gets saved to .tscn
		add_child(clone, false, Node.INTERNAL_MODE_BACK)
		_gear_bodies.append(clone)
		_gear_sprites.append(clone_spr)

func _update_movement_cache() -> void:
	var pos_d = move_dist_pos
	var neg_d = move_dist_neg
	var angle_deg = move_angle

	# Legacy fallback if legacy direction / distance were provided
	if move_direction != "" and move_direction != "CUSTOM" and is_equal_approx(angle_deg, 0.0) and is_equal_approx(pos_d, 200.0) and is_equal_approx(neg_d, 200.0) and not is_equal_approx(move_distance, 200.0):
		match move_direction:
			"+X":
				angle_deg = 0.0
				pos_d = move_distance
				neg_d = 0.0
			"-X":
				angle_deg = 0.0
				pos_d = 0.0
				neg_d = move_distance
			"Y", "BOTH_Y":
				angle_deg = 90.0
				pos_d = move_distance
				neg_d = move_distance
			"+Y":
				angle_deg = 90.0
				pos_d = move_distance
				neg_d = 0.0
			"-Y":
				angle_deg = 90.0
				pos_d = 0.0
				neg_d = move_distance
			_:
				angle_deg = 0.0
				pos_d = move_distance
				neg_d = move_distance

	var rad = deg_to_rad(angle_deg)
	_move_dir_vec = Vector2(cos(rad), sin(rad))
	_center_offset = (pos_d - neg_d) * 0.5
	_amplitude = (pos_d + neg_d) * 0.5
	var total_span = pos_d + neg_d
	_has_movement = (total_span > 0.0) and (move_speed > 0.0)

	if _has_movement:
		_travel_time = total_span / max(1.0, move_speed)
		_cycle_duration = 2.0 * (_travel_time + direction_change_delay)
	else:
		_travel_time = 0.0
		_cycle_duration = 0.0

	# Update clone relative positions
	for i in range(1, _gear_bodies.size()):
		var body = _gear_bodies[i]
		if body:
			body.position = _move_dir_vec * (float(i) * gear_spacing)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Rotate all gear sprites
	if rotation_speed != 0.0:
		for spr in _gear_sprites:
			if spr:
				spr.rotation += rotation_speed * delta

	# Move along angle axis with positive and negative travel distances + endpoint delays
	if _has_movement:
		_elapsed_time += delta
		if _elapsed_time < start_delay:
			return

		var t_active = _elapsed_time - start_delay
		var offset_scalar: float = 0.0
		var pos_d = move_dist_pos
		var neg_d = move_dist_neg
		var t_pause = direction_change_delay

		if pos_d > 0.0 and neg_d <= 0.001:
			# Single direction: Forward (0 to +pos_d)
			var t_one = pos_d / max(1.0, move_speed)
			if t_pause > 0.0:
				var cycle = 2.0 * (t_one + t_pause)
				var t = fmod(t_active, cycle)
				if t < t_one:
					# 0 -> +pos_d
					var s = (1.0 - cos((t / t_one) * PI)) * 0.5
					offset_scalar = pos_d * s
				elif t < t_one + t_pause:
					# Paused at positive end
					offset_scalar = pos_d
				elif t < 2.0 * t_one + t_pause:
					# +pos_d -> 0
					var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
					offset_scalar = pos_d * (1.0 - s)
				else:
					# Paused at start (0)
					offset_scalar = 0.0
			else:
				var phase = t_active * (move_speed / max(1.0, pos_d)) * PI
				offset_scalar = pos_d * 0.5 * (1.0 - cos(phase))

		elif neg_d > 0.0 and pos_d <= 0.001:
			# Single direction: Reverse (0 to -neg_d)
			var t_one = neg_d / max(1.0, move_speed)
			if t_pause > 0.0:
				var cycle = 2.0 * (t_one + t_pause)
				var t = fmod(t_active, cycle)
				if t < t_one:
					# 0 -> -neg_d
					var s = (1.0 - cos((t / t_one) * PI)) * 0.5
					offset_scalar = -neg_d * s
				elif t < t_one + t_pause:
					# Paused at negative end
					offset_scalar = -neg_d
				elif t < 2.0 * t_one + t_pause:
					# -neg_d -> 0
					var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
					offset_scalar = -neg_d * (1.0 - s)
				else:
					# Paused at start (0)
					offset_scalar = 0.0
			else:
				var phase = t_active * (move_speed / max(1.0, neg_d)) * PI
				offset_scalar = -neg_d * 0.5 * (1.0 - cos(phase))

		else:
			# Bidirectional spanning across origin (-neg_d to +pos_d)
			var t_pos = pos_d / max(1.0, move_speed)
			var t_neg = neg_d / max(1.0, move_speed)
			var t_span = (pos_d + neg_d) / max(1.0, move_speed)

			if t_pause > 0.0:
				var cycle = 2.0 * t_span + 2.0 * t_pause
				var t = fmod(t_active, cycle)
				if t < t_pos:
					# 0 -> +pos_d
					var s = (1.0 - cos((t / max(0.001, t_pos)) * (PI * 0.5)))
					offset_scalar = pos_d * s
				elif t < t_pos + t_pause:
					# Paused at +pos_d
					offset_scalar = pos_d
				elif t < t_pos + t_pause + t_span:
					# +pos_d -> -neg_d
					var s = (1.0 - cos(((t - (t_pos + t_pause)) / max(0.001, t_span)) * PI)) * 0.5
					offset_scalar = pos_d - (pos_d + neg_d) * s
				elif t < t_pos + 2.0 * t_pause + t_span:
					# Paused at -neg_d
					offset_scalar = -neg_d
				else:
					# -neg_d -> 0
					var s = (1.0 - cos(((t - (t_pos + 2.0 * t_pause + t_span)) / max(0.001, t_neg)) * (PI * 0.5)))
					offset_scalar = -neg_d * (1.0 - s)
			else:
				var phase = t_active * (move_speed / max(1.0, _amplitude))
				offset_scalar = _center_offset + _amplitude * sin(phase)

		position = start_pos + _move_dir_vec * offset_scalar

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

func _apply_theme() -> void:
	if sprite_gear == null and has_node("Sprite2D"):
		sprite_gear = get_node("Sprite2D") as Sprite2D

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	var g_tex = WorldThemeRegistry.get_gear_texture(theme_id)
	if g_tex:
		for spr in _gear_sprites:
			if spr:
				spr.texture = g_tex

func reset() -> void:
	_elapsed_time = 0.0
	position = start_pos

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
	if not is_in_editor():
		return

	var p_neg = -_move_dir_vec * move_dist_neg
	var p_pos = _move_dir_vec * move_dist_pos

	var line_col = Color(0.0, 0.9, 1.0, 0.85)    # Bright Cyan dashed line
	var end_col = Color(1.0, 0.35, 0.35, 0.95)   # Red-orange endpoint caps
	var origin_col = Color(0.2, 1.0, 0.4, 0.95)  # Green origin marker

	# Draw dashed trajectory guideline
	_draw_dashed_line(p_neg, p_pos, line_col, 2.5, 12.0)

	# Draw Origin center point
	draw_circle(Vector2.ZERO, 5.0, origin_col)

	# Draw perpendicular end caps
	var perp = _move_dir_vec.orthogonal() * 14.0
	draw_line(p_neg - perp, p_neg + perp, end_col, 3.0)
	draw_line(p_pos - perp, p_pos + perp, end_col, 3.0)

	# If gear_count > 1, draw resting points for each additional gear
	if gear_count > 1:
		for i in range(1, gear_count):
			var g_pos = _move_dir_vec * (float(i) * gear_spacing)
			draw_circle(g_pos, 4.5, Color(1.0, 0.85, 0.2, 0.9))

	# Draw helpful text label showing distances and delays
	var font = ThemeDB.fallback_font
	if font:
		var total_span = move_dist_pos + move_dist_neg
		var label_str = "Distance: %.0f (-%.0f / +%.0f)" % [total_span, move_dist_neg, move_dist_pos]
		if direction_change_delay > 0.0 or start_delay > 0.0:
			label_str += " | Delay: %.1fs" % [direction_change_delay + start_delay]
		if gear_count > 1:
			label_str += " | %d Gears (Gap: %.0f)" % [gear_count, gear_spacing]
		draw_string(font, p_pos + Vector2(10, 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float = 12.0) -> void:
	var diff = to - from
	var dist = diff.length()
	if dist <= 0.001:
		return
	var dir = diff / dist
	var curr = 0.0
	while curr < dist:
		var next_p = min(curr + dash_len, dist)
		draw_line(from + dir * curr, from + dir * next_p, color, width)
		curr += dash_len * 2.0
