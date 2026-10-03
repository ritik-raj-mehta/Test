@tool
extends Node2D
class_name MovingGearController

## Unified obstacle controller for stationary rotating gears, linear moving gears, fixed-rod moving gears, and static rod barriers.
## Combines gear_r, gear_m, gear_with_rod, and gear_rod into a single, high-performance, tool-capable scene.

# ==============================================================================
# 1. CORE PROPERTIES & EXPORTS
# ==============================================================================

@export_group("Configuration")
@export var has_rod: bool = false:
	set(v):
		has_rod = v
		_has_rod_explicit = true
		_update_all()

@export var has_gear: bool = true:
	set(v):
		has_gear = v
		_has_gear_explicit = true
		_update_all()

@export var is_lethal: bool = true:
	set(v):
		is_lethal = v
		gear_is_lethal = v

@export var gear_is_lethal: bool = true
@export var rod_is_lethal: bool = false:
	set(v):
		rod_is_lethal = v
		if rod_body:
			rod_body.set_meta("is_lethal", rod_is_lethal)

@export var rod_has_collision: bool = false:
	set(v):
		rod_has_collision = v
		_update_rod_dimensions()

# Rod Dimensions
@export_group("Rod")
@export var length: float = 200.0:
	set(v):
		length = max(1.0, v)
		if not _has_rod_explicit and not _has_gear_explicit:
			has_rod = true
		_update_all()

@export var rod_breadth: float = 8.0:
	set(v):
		rod_breadth = max(1.0, v)
		_update_rod_dimensions()

@export var breadth: float = 8.0:
	set(v):
		rod_breadth = max(1.0, v)
	get:
		return rod_breadth

@export var width: float = 8.0:
	set(v):
		rod_breadth = max(1.0, v)
	get:
		return rod_breadth

# Gear Movement & Oscillation / Loop
@export_group("Movement")
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

@export var move_distance: float = 200.0:
	set(v):
		move_distance = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_angle: float = 0.0: # degrees: 0 = Right (+X), 90 = Down (+Y), 180 = Left (-X), -90 = Up (-Y)
	set(v):
		move_angle = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_enum("X", "+X", "-X", "Y", "+Y", "-Y", "CUSTOM", "+X (Right)", "-X (Left)", "+Y (Down)", "-Y (Up)") var move_direction: String = "X":
	set(v):
		move_direction = v
		_sync_direction_enum()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var loop_reset: bool = false: # true = continuous wrap-around along rod; false = ping-pong oscillation
	set(v):
		loop_reset = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var start_delay: float = 0.0:
	set(v):
		start_delay = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var direction_change_delay: float = 0.0: # Pause duration in seconds at each end
	set(v):
		direction_change_delay = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var delay: float = 0.0: # Backward compatibility alias for direction_change_delay
	set(v):
		direction_change_delay = max(0.0, v)
	get:
		return direction_change_delay
		if Engine.is_editor_hint():
			queue_redraw()

@export var gear_scale: float = 1.0:
	set(v):
		gear_scale = max(0.1, v)
		_update_gear_scales()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(0, 20, 1) var gear_count: int = 1:
	set(v):
		gear_count = clampi(v, 0, 20)
		if gear_count == 0 and not _has_gear_explicit:
			has_gear = false
		elif gear_count > 0 and not _has_gear_explicit:
			has_gear = true
		_rebuild_gears()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(0.0, 5000.0, 1.0, "or_greater") var gear_spacing: float = 100.0:
	set(v):
		gear_spacing = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_group("Interval Movement & Speed Curve")
@export var enable_interval_movement: bool = false:
	set(v):
		enable_interval_movement = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_time: float = 3.0: # Time duration in seconds per interval movement cycle
	set(v):
		interval_time = max(0.1, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_speed: float = 150.0: # Fixed movement speed during interval
	set(v):
		interval_speed = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var enable_speed_modulation: bool = false: # Smooth speed wave: start move -> slow down -> speed up -> slow down
	set(v):
		enable_speed_modulation = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var min_speed_scale: float = 0.25: # Minimum speed multiplier during slow phase
	set(v):
		min_speed_scale = clampf(v, 0.0, 3.0)
		_update_movement_cache()

@export var max_speed_scale: float = 1.75: # Peak speed multiplier during fast phase
	set(v):
		max_speed_scale = max(0.1, v)
		_update_movement_cache()

@export var speed_pulses_per_interval: float = 2.0: # Number of speed-up/slow-down pulses per interval
	set(v):
		speed_pulses_per_interval = max(0.5, v)
		_update_movement_cache()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

# ==============================================================================
# 2. INTERNAL STATE & NODE REFERENCES
# ==============================================================================

@onready var rod_body: StaticBody2D = $RodBody if has_node("RodBody") else null
@onready var rod_sprite: Sprite2D = $RodBody/RodSprite if has_node("RodBody/RodSprite") else ($RodSprite if has_node("RodSprite") else null)
@onready var rod_col: CollisionShape2D = $RodBody/RodCollisionShape if has_node("RodBody/RodCollisionShape") else ($RodCollisionShape if has_node("RodCollisionShape") else null)

@onready var gear_body: StaticBody2D = $GearBody if has_node("GearBody") else null
@onready var sprite_gear: Sprite2D = $GearBody/Sprite2D if has_node("GearBody/Sprite2D") else ($Sprite2D if has_node("Sprite2D") else null)
@onready var col_shape: CollisionShape2D = $GearBody/CollisionShape2D if has_node("GearBody/CollisionShape2D") else ($CollisionShape2D if has_node("CollisionShape2D") else null)

var _has_rod_explicit: bool = false
var _has_gear_explicit: bool = false

var _move_dir_vec: Vector2 = Vector2.RIGHT
var _center_offset: float = 0.0
var _amplitude: float = 0.0
var _total_span: float = 0.0
var _has_movement: bool = false
var _elapsed_time: float = 0.0
var _progress: float = 0.0

var _gear_bodies: Array[StaticBody2D] = []
var _gear_sprites: Array[Sprite2D] = []

# ==============================================================================
# 3. LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	add_to_group("obstacle")
	_resolve_nodes()
	_auto_detect_mode_if_needed()
	_update_all()

func update_components() -> void:
	_resolve_nodes()
	_auto_detect_mode_if_needed()
	_update_all()

func _update_all() -> void:
	_rebuild_gears()
	_update_movement_cache()
	_apply_theme()
	if Engine.is_editor_hint():
		queue_redraw()

func _resolve_nodes() -> void:
	if rod_body == null and has_node("RodBody"):
		rod_body = get_node("RodBody") as StaticBody2D
	if rod_sprite == null:
		if has_node("RodBody/RodSprite"):
			rod_sprite = get_node("RodBody/RodSprite") as Sprite2D
		elif has_node("RodSprite"):
			rod_sprite = get_node("RodSprite") as Sprite2D
	if rod_col == null:
		if has_node("RodBody/RodCollisionShape"):
			rod_col = get_node("RodBody/RodCollisionShape") as CollisionShape2D
		elif has_node("RodCollisionShape"):
			rod_col = get_node("RodCollisionShape") as CollisionShape2D

	if gear_body == null and has_node("GearBody"):
		gear_body = get_node("GearBody") as StaticBody2D
	if sprite_gear == null:
		if has_node("GearBody/Sprite2D"):
			sprite_gear = get_node("GearBody/Sprite2D") as Sprite2D
		elif has_node("Sprite2D"):
			sprite_gear = get_node("Sprite2D") as Sprite2D
	if col_shape == null:
		if has_node("GearBody/CollisionShape2D"):
			col_shape = get_node("GearBody/CollisionShape2D") as CollisionShape2D
		elif has_node("CollisionShape2D"):
			col_shape = get_node("CollisionShape2D") as CollisionShape2D

func _auto_detect_mode_if_needed() -> void:
	if _has_rod_explicit or _has_gear_explicit:
		return
	if gear_count == 0:
		has_rod = true
		has_gear = false
	elif loop_reset or (has_rod and has_gear):
		has_rod = true
		has_gear = true
	elif move_speed <= 0.0 and move_dist_pos <= 0.0 and move_dist_neg <= 0.0 and move_distance <= 0.0:
		has_rod = false
		has_gear = true
	else:
		has_rod = false
		has_gear = true

# ==============================================================================
# 4. GEAR REBUILDING & POOLING
# ==============================================================================

func _update_gear_scales() -> void:
	var base_scale = Vector2(0.5, 0.5) * gear_scale
	for body in _gear_bodies:
		if body:
			var spr = body.get_node_or_null("Sprite2D") as Sprite2D
			if spr:
				spr.scale = base_scale
			var col = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if col and col.shape and col.shape is CircleShape2D:
				if not col.shape.resource_local_to_scene:
					col.shape = col.shape.duplicate()
				(col.shape as CircleShape2D).radius = 44.15 * gear_scale

func _rebuild_gears() -> void:
	_resolve_nodes()

	# Clear previous clones
	for child in get_children(true):
		if child != rod_body and child != gear_body and (child.name.begins_with("GearBody_Clone_") or child.is_in_group("gear_clone")):
			child.queue_free()
			remove_child(child)

	_gear_bodies.clear()
	_gear_sprites.clear()

	if not has_gear or gear_count == 0:
		if gear_body:
			gear_body.visible = false
			gear_body.process_mode = Node.PROCESS_MODE_DISABLED
			if col_shape:
				col_shape.disabled = true
		return

	if gear_body:
		gear_body.visible = true
		gear_body.process_mode = Node.PROCESS_MODE_INHERIT
		gear_body.add_to_group("obstacle")
		gear_body.set_meta("is_lethal", gear_is_lethal)
		if col_shape:
			col_shape.disabled = false
		_gear_bodies.append(gear_body)
		if sprite_gear:
			_gear_sprites.append(sprite_gear)

	# Spawn clone gears
	var target_count = max(1, gear_count)
	for i in range(1, target_count):
		if gear_body:
			var clone := gear_body.duplicate() as StaticBody2D
			clone.name = "GearBody_Clone_%d" % i
			clone.add_to_group("obstacle")
			clone.add_to_group("gear_clone")
			clone.set_meta("is_lethal", gear_is_lethal)
			clone.collision_layer = gear_body.collision_layer
			clone.collision_mask = gear_body.collision_mask
			# Node.INTERNAL_MODE_BACK guarantees clones are never saved to .tscn files
			add_child(clone, false, Node.INTERNAL_MODE_BACK)
			_gear_bodies.append(clone)
			var spr = clone.get_node_or_null("Sprite2D") as Sprite2D
			if spr:
				_gear_sprites.append(spr)

	_apply_theme()
	_update_gear_scales()

# ==============================================================================
# 5. MOVEMENT & CACHES
# ==============================================================================

func _sync_direction_enum() -> void:
	match move_direction:
		"+X", "+X (Right)", "RIGHT":
			move_angle = 0.0
			if move_dist_pos <= 0.0 and move_distance > 0.0:
				move_dist_pos = move_distance
				move_dist_neg = 0.0
		"-X", "-X (Left)", "LEFT":
			move_angle = 180.0
			if move_dist_pos <= 0.0 and move_distance > 0.0:
				move_dist_pos = move_distance
				move_dist_neg = 0.0
		"+Y", "+Y (Down)", "DOWN":
			move_angle = 90.0
			if move_dist_pos <= 0.0 and move_distance > 0.0:
				move_dist_pos = move_distance
				move_dist_neg = 0.0
		"-Y", "-Y (Up)", "UP":
			move_angle = -90.0
			if move_dist_pos <= 0.0 and move_distance > 0.0:
				move_dist_pos = move_distance
				move_dist_neg = 0.0
		"Y", "BOTH_Y":
			move_angle = 90.0
		"X":
			move_angle = 0.0

func _update_movement_cache() -> void:
	var rad = deg_to_rad(move_angle)
	_move_dir_vec = Vector2(cos(rad), sin(rad))

	var pos_d = move_dist_pos
	var neg_d = move_dist_neg

	# Legacy fallback if legacy direction / distance were provided
	if pos_d <= 0.0 and neg_d <= 0.0 and move_distance > 0.0:
		if loop_reset:
			pos_d = move_distance
			neg_d = 0.0
		else:
			pos_d = move_distance * 0.5
			neg_d = move_distance * 0.5

	_total_span = pos_d + neg_d
	_center_offset = (pos_d - neg_d) * 0.5
	_amplitude = _total_span * 0.5
	_has_movement = has_gear and (_total_span > 0.0) and (move_speed > 0.0)

	_update_rod_dimensions()
	_update_gears_positions(0.0)

# ==============================================================================
# 6. ROD DIMENSIONS & POSITIONING
# ==============================================================================

func _update_rod_dimensions() -> void:
	_resolve_nodes()
	if not rod_body:
		return

	if not has_rod:
		rod_body.visible = false
		rod_body.process_mode = Node.PROCESS_MODE_DISABLED
		if rod_col:
			rod_col.disabled = true
		return

	rod_body.visible = true
	rod_body.process_mode = Node.PROCESS_MODE_INHERIT
	rod_body.add_to_group("obstacle")
	rod_body.set_meta("is_lethal", rod_is_lethal)

	var rod_len: float = 0.0
	var rod_center: Vector2 = Vector2.ZERO

	if has_gear and _total_span > 0.0:
		rod_len = _total_span
		if move_dist_pos > 0.0 and move_dist_neg <= 0.001:
			rod_center = _move_dir_vec * (rod_len * 0.5)
		elif move_dist_neg > 0.0 and move_dist_pos <= 0.001:
			rod_center = -_move_dir_vec * (rod_len * 0.5)
		else:
			rod_center = _move_dir_vec * _center_offset
	else:
		# Static rod barrier centered at node origin
		rod_len = max(length, move_distance)
		rod_center = Vector2.ZERO

	var rod_thick: float = max(breadth, rod_breadth)
	rod_body.position = rod_center
	rod_body.rotation = deg_to_rad(move_angle)

	if rod_body:
		if not rod_has_collision:
			rod_body.collision_layer = 0
			rod_body.collision_mask = 0

	if rod_col:
		rod_col.disabled = not rod_has_collision
		if not rod_col.shape or not rod_col.shape is RectangleShape2D:
			rod_col.shape = RectangleShape2D.new()
		elif not rod_col.shape.resource_local_to_scene:
			rod_col.shape = rod_col.shape.duplicate()
		(rod_col.shape as RectangleShape2D).size = Vector2(rod_len, rod_thick)

	if rod_sprite and rod_sprite.texture:
		var tex_h = float(rod_sprite.texture.get_height())
		var tex_w = float(rod_sprite.texture.get_width())
		rod_sprite.position = Vector2.ZERO
		rod_sprite.rotation = PI * 0.5
		if tex_h > 0.0:
			rod_sprite.scale.y = rod_len / tex_h
		if tex_w > 0.0:
			rod_sprite.scale.x = rod_thick / tex_w

# ==============================================================================
# 7. PHYSICS PROCESS & MOVEMENT EXECUTION
# ==============================================================================

func _get_effective_speed(t_active: float) -> float:
	var base_spd = interval_speed if enable_interval_movement else move_speed
	if not enable_speed_modulation:
		return base_spd

	# Speed modulation wave: start move a little -> slow down -> speed up -> slow down
	var duration = interval_time if (enable_interval_movement and interval_time > 0.0) else max(0.5, _total_span / max(1.0, base_spd))
	var phase = (t_active / max(0.1, duration)) * speed_pulses_per_interval * TAU
	var wave = 0.5 * (1.0 + sin(phase))
	var mult = lerpf(min_speed_scale, max_speed_scale, wave)
	return base_spd * mult

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _has_movement and not (has_gear and rotation_speed != 0.0):
		return

	_elapsed_time += delta
	var t_active = max(0.0, _elapsed_time - start_delay)
	var cur_spd = _get_effective_speed(t_active)

	# Spin all gear sprites with speed-proportional rotation
	if has_gear and rotation_speed != 0.0:
		var base_ref = interval_speed if enable_interval_movement else move_speed
		var spin_scale = (cur_spd / max(1.0, base_ref)) if base_ref > 0.0 else 1.0
		for spr in _gear_sprites:
			if spr:
				spr.rotation += rotation_speed * spin_scale * delta

	# Process movement
	if _has_movement:
		if _elapsed_time < start_delay:
			return

		if loop_reset:
			# Continuous wrap-around along the rod track (respawns cleanly at origin in loop)
			_progress += (cur_spd / max(1.0, _total_span)) * delta
			if _progress >= 1.0:
				_progress = fmod(_progress, 1.0)
			_update_gears_positions(0.0)
		else:
			# Ping-pong oscillation with endpoint delays
			var offset_scalar: float = 0.0
			var pos_d = move_dist_pos
			var neg_d = move_dist_neg
			var t_pause = direction_change_delay

			if pos_d > 0.0 and neg_d <= 0.001:
				var t_one = pos_d / max(1.0, cur_spd)
				if t_pause > 0.0:
					var cycle = 2.0 * (t_one + t_pause)
					var t = fmod(t_active, cycle)
					if t < t_one:
						var s = (1.0 - cos((t / t_one) * PI)) * 0.5
						offset_scalar = pos_d * s
					elif t < t_one + t_pause:
						offset_scalar = pos_d
					elif t < 2.0 * t_one + t_pause:
						var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
						offset_scalar = pos_d * (1.0 - s)
					else:
						offset_scalar = 0.0
				else:
					var phase = t_active * (cur_spd / max(1.0, pos_d)) * PI
					offset_scalar = pos_d * 0.5 * (1.0 - cos(phase))

			elif neg_d > 0.0 and pos_d <= 0.001:
				var t_one = neg_d / max(1.0, cur_spd)
				if t_pause > 0.0:
					var cycle = 2.0 * (t_one + t_pause)
					var t = fmod(t_active, cycle)
					if t < t_one:
						var s = (1.0 - cos((t / t_one) * PI)) * 0.5
						offset_scalar = -neg_d * s
					elif t < t_one + t_pause:
						offset_scalar = -neg_d
					elif t < 2.0 * t_one + t_pause:
						var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
						offset_scalar = -neg_d * (1.0 - s)
					else:
						offset_scalar = 0.0
				else:
					var phase = t_active * (cur_spd / max(1.0, neg_d)) * PI
					offset_scalar = -neg_d * 0.5 * (1.0 - cos(phase))

			else:
				var t_pos = pos_d / max(1.0, cur_spd)
				var t_neg = neg_d / max(1.0, cur_spd)
				var t_span = (pos_d + neg_d) / max(1.0, cur_spd)
				var cycle = 2.0 * t_span + 2.0 * t_pause
				var t = fmod(t_active, cycle)

				if t < t_pos:
					var s = sin((t / max(0.001, t_pos)) * (PI * 0.5))
					offset_scalar = pos_d * s
				elif t < t_pos + t_pause:
					offset_scalar = pos_d
				elif t < t_pos + t_pause + t_span:
					var u = t - (t_pos + t_pause)
					var s = (1.0 - cos((u / max(0.001, t_span)) * PI)) * 0.5
					offset_scalar = pos_d - (pos_d + neg_d) * s
				elif t < t_pos + 2.0 * t_pause + t_span:
					offset_scalar = -neg_d
				else:
					var v = t - (t_pos + 2.0 * t_pause + t_span)
					var s = cos((v / max(0.001, t_neg)) * (PI * 0.5))
					offset_scalar = -neg_d * s

			_update_gears_positions(offset_scalar)

func _update_gears_positions(offset_scalar: float) -> void:
	var count = _gear_bodies.size()
	if count == 0 or not has_gear:
		return

	var effective_spacing = gear_spacing
	if is_zero_approx(effective_spacing):
		effective_spacing = _total_span / float(count)

	if loop_reset:
		var track_start = -_move_dir_vec * move_dist_neg
		for i in range(count):
			var body = _gear_bodies[i]
			if not body:
				continue
			var gear_prog = fposmod(_progress + (float(i) * effective_spacing / max(1.0, _total_span)), 1.0)
			var travel_offset = gear_prog * _total_span
			body.position = track_start + (_move_dir_vec * travel_offset)
	else:
		for i in range(count):
			var body = _gear_bodies[i]
			if not body:
				continue
			var spacing_offset = _move_dir_vec * (float(i) * gear_spacing)
			body.position = (_move_dir_vec * offset_scalar) + spacing_offset

# ==============================================================================
# 8. WORLD THEME & RESET
# ==============================================================================

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

func _apply_theme() -> void:
	_resolve_nodes()

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	if rod_sprite:
		var r_tex = WorldThemeRegistry.get_gear_rod_texture(theme_id)
		if r_tex:
			rod_sprite.texture = r_tex
			_update_rod_dimensions()

	var g_tex = WorldThemeRegistry.get_gear_texture(theme_id)
	if g_tex:
		for spr in _gear_sprites:
			if spr:
				spr.texture = g_tex

	_update_gear_scales()

func reset() -> void:
	# Keep current gear movement phase & position intact on player death/respawn
	pass

# ==============================================================================
# 9. EDITOR VISUALS & GIZMOS
# ==============================================================================

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

	var font = ThemeDB.fallback_font

	# Draw movement guidelines when gear movement is present
	if has_gear and _has_movement:
		var p_neg = -_move_dir_vec * move_dist_neg
		var p_pos = _move_dir_vec * move_dist_pos

		var line_col = Color(0.0, 0.9, 1.0, 0.85)    # Bright Cyan dashed line
		var end_col = Color(1.0, 0.35, 0.35, 0.95)   # Red-orange endpoint caps
		var origin_col = Color(0.2, 1.0, 0.4, 0.95)  # Green origin marker

		_draw_dashed_line(p_neg, p_pos, line_col, 2.5, 12.0)
		draw_circle(Vector2.ZERO, 5.0, origin_col)

		var perp = _move_dir_vec.orthogonal() * 14.0
		draw_line(p_neg - perp, p_neg + perp, end_col, 3.0)
		draw_line(p_pos - perp, p_pos + perp, end_col, 3.0)

		if gear_count > 1:
			for i in range(1, gear_count):
				var g_pos = _move_dir_vec * (float(i) * gear_spacing)
				draw_circle(g_pos, 4.5, Color(1.0, 0.85, 0.2, 0.9))

		if font:
			var label_str = "Distance: %.0f (-%.0f / +%.0f)" % [_total_span, move_dist_neg, move_dist_pos]
			if loop_reset:
				label_str += " [Loop Mode]"
			elif direction_change_delay > 0.0 or start_delay > 0.0:
				label_str += " | Delay: %.1fs" % [direction_change_delay + start_delay]
			if gear_count > 1:
				label_str += " | %d Gears (Gap: %.0f)" % [gear_count, gear_spacing]
			draw_string(font, p_pos + Vector2(10, 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))

	elif has_rod and not has_gear:
		# Static rod indicator
		draw_circle(Vector2.ZERO, 4.0, Color(0.2, 1.0, 0.4, 0.8))
		if font:
			var rod_len = max(length, move_distance)
			var rod_thick = max(breadth, rod_breadth)
			var label_str = "Rod Barrier: %.0f x %.0f" % [rod_len, rod_thick]
			draw_string(font, Vector2(10, -10), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width_val: float, dash_len: float = 12.0) -> void:
	var diff = to - from
	var dist = diff.length()
	if dist <= 0.001:
		return
	var dir = diff / dist
	var curr = 0.0
	while curr < dist:
		var next_p = min(curr + dash_len, dist)
		draw_line(from + dir * curr, from + dir * next_p, color, width_val)
		curr += dash_len * 2.0
