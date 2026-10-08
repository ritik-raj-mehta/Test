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

@export var stop_at_end: bool = false: # true = gear moves to endpoint/destination and stops; false = loop/ping-pong continuously
	set(v):
		stop_at_end = v
		_has_reached_end = false
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

@export_group("Gear Grouping System")
@export_range(1, 20, 1) var group_count: int = 1:
	set(v):
		group_count = clampi(v, 1, 20)
		_rebuild_gears()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(1, 20, 1) var gears_per_group: int = 1:
	set(v):
		gears_per_group = clampi(v, 1, 20)
		_rebuild_gears()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(0.0, 5000.0, 1.0, "or_greater") var group_spacing: float = 300.0:
	set(v):
		group_spacing = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var group_phase_stagger: float = 0.0: # Time delay in seconds between movement of successive groups
	set(v):
		group_phase_stagger = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_group("Snake / Wave Form System")
## Enables snake wave form mode where multiple gears move in an undulating wave following each other
@export var is_snake_wave: bool = false:
	set(v):
		is_snake_wave = v
		_rebuild_gears()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Total number of gears in the snake wave
@export_range(1, 40, 1) var snake_gear_count: int = 12:
	set(v):
		snake_gear_count = clampi(v, 1, 40)
		_rebuild_gears()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Vertical distance between each gear tier/row in the snake (positive = downward)
@export var snake_spacing_y: float = 120.0:
	set(v):
		snake_spacing_y = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Horizontal spacing between each gear tier (0.0 for vertical column)
@export var snake_spacing_x: float = 0.0:
	set(v):
		snake_spacing_x = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Time delay (lag in seconds) that each gear follows the previous gear (creates the trailing snake effect)
@export var snake_delay: float = 0.2:
	set(v):
		snake_delay = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Wave phase shift mode: "Time Delay (Follow)" or "Wave Cycles (Full Wave)"
@export_enum("Time Delay (Follow)", "Wave Cycles (Full Wave)") var snake_mode: String = "Time Delay (Follow)":
	set(v):
		snake_mode = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Number of full sine wave cycles across the entire snake when using Wave Cycles mode
@export var snake_wave_cycles: float = 1.0:
	set(v):
		snake_wave_cycles = max(0.1, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

## Whether to spawn a track rod for every gear in the snake (matching the reference screenshot)
@export var snake_show_rods: bool = true:
	set(v):
		snake_show_rods = v
		_update_rod_dimensions()
		if Engine.is_editor_hint():
			queue_redraw()

## Invert follow direction (bottom-to-top wave instead of top-to-bottom)
@export var snake_reverse_follow: bool = false:
	set(v):
		snake_reverse_follow = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

func _get_snake_gear_time_offset(i: int, target_count: int, base_spd: float) -> float:
	var idx = (target_count - 1 - i) if snake_reverse_follow else i
	if snake_mode == "Wave Cycles (Full Wave)":
		var pos_d = move_dist_pos
		var neg_d = move_dist_neg
		var t_pause = direction_change_delay
		var t_span = (pos_d + neg_d) / max(1.0, base_spd)
		var cycle = 2.0 * t_span + 2.0 * t_pause
		if cycle <= 0.001:
			cycle = 1.0
		var delay_per_gear = (cycle * snake_wave_cycles) / float(max(1, target_count))
		return float(idx) * delay_per_gear
	else:
		return float(idx) * snake_delay

@export_group("Interval Movement & Speed Curve")
@export var enable_interval_movement: bool = false:
	set(v):
		enable_interval_movement = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_move_time: float = 2.0: # Time in seconds gear moves at normal speed
	set(v):
		interval_move_time = max(0.1, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_pause_time: float = 1.0: # Time in seconds gear slows down or pauses
	set(v):
		interval_pause_time = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_slow_factor: float = 0.0: # Speed factor during pause phase (0.0 = full stop, 0.2 = slow down)
	set(v):
		interval_slow_factor = clampf(v, 0.0, 1.0)
		_update_movement_cache()

@export var interval_time: float = 3.0: # Total interval cycle duration fallback
	set(v):
		interval_time = max(0.1, v)
		interval_move_time = interval_time * 0.67
		interval_pause_time = interval_time * 0.33
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var interval_speed: float = 150.0: # Fixed movement speed during move phase
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

@export_group("ZigZag & Waypoint Path")
@export var is_zigzag: bool = false:
	set(v):
		is_zigzag = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export_enum("Stepped (Orthogonal)", "Diagonal", "Custom") var zigzag_pattern: String = "Stepped (Orthogonal)":
	set(v):
		zigzag_pattern = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var zigzag_width: float = 400.0:
	set(v):
		zigzag_width = max(10.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var zigzag_angle: float = 45.0: # Angle in degrees for diagonal zigzag segments (e.g. 30, 45, 60)
	set(v):
		zigzag_angle = clampf(v, 5.0, 85.0)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var zigzag_height: float = 180.0: # Vertical step height between tiers in stepped track
	set(v):
		zigzag_height = max(10.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var zigzag_count: int = 4:
	set(v):
		zigzag_count = clampi(v, 1, 30)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var zigzag_start_from_bottom: bool = false:
	set(v):
		zigzag_start_from_bottom = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var flip_zigzag: bool = false: # Horizontally flips zigzag (Starts right instead of left)
	set(v):
		flip_zigzag = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var custom_waypoints: Array = []:
	set(v):
		custom_waypoints = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var enable_node_pause: bool = true: # Pause duration at track points
	set(v):
		enable_node_pause = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var node_pause_time: float = 0.5: # Default pause duration in seconds at each point/node
	set(v):
		node_pause_time = max(0.0, v)
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var point_delays: Array = []: # Specific delays [d0, d1, d2, ...] per point index
	set(v):
		point_delays = v
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var point_delays_str: String = "": # Comma-separated point delays, e.g. "0.5, 1.0, 0.2, 1.5"
	set(v):
		point_delays_str = v
		_parse_point_delays_str()
		_update_movement_cache()
		if Engine.is_editor_hint():
			queue_redraw()

@export var show_track_rods: bool = true:
	set(v):
		show_track_rods = v
		_update_rod_dimensions()
		if Engine.is_editor_hint():
			queue_redraw()

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
var _has_reached_end: bool = false
var _elapsed_time: float = 0.0
var _motion_accum_time: float = 0.0
var _progress: float = 0.0

var _gear_bodies: Array[StaticBody2D] = []
var _gear_sprites: Array[Sprite2D] = []

var _path_points: Array[Vector2] = []
var _segment_lengths: Array[float] = []
var _total_path_length: float = 0.0

# ==============================================================================
# 3. LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	add_to_group("obstacle")
	_resolve_nodes()
	_auto_detect_mode_if_needed()
	_update_all()
	if not Engine.is_editor_hint():
		set_physics_process(_has_movement or (has_gear and rotation_speed != 0.0))

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

	var target_count = gear_count
	if is_snake_wave:
		target_count = maxi(1, snake_gear_count)
	elif group_count > 1:
		target_count = group_count * max(1, gears_per_group)

	if not has_gear or target_count == 0:
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

func _parse_point_delays_str() -> void:
	if point_delays_str.strip_edges() == "":
		return
	var parts = point_delays_str.split(",")
	var new_delays: Array = []
	for p in parts:
		var s = p.strip_edges()
		if s.is_valid_float():
			new_delays.append(maxf(0.0, s.to_float()))
	if not new_delays.is_empty():
		point_delays = new_delays


func get_point_delay(idx: int) -> float:
	if idx >= 0 and idx < point_delays.size() and point_delays[idx] != null:
		return maxf(0.0, float(point_delays[idx]))
	if enable_node_pause:
		return node_pause_time
	return 0.0


func _rebuild_path_points() -> void:
	_path_points.clear()
	_segment_lengths.clear()
	_total_path_length = 0.0

	if not custom_waypoints.is_empty():
		for pt in custom_waypoints:
			_path_points.append(Vector2(pt))
	elif is_zigzag:
		var half_w = zigzag_width * 0.5
		var dir_mult = -1.0 if flip_zigzag else 1.0

		if zigzag_pattern == "Diagonal":
			var rad_ang = deg_to_rad(clampf(zigzag_angle, 5.0, 85.0))
			var step_h = half_w * tan(rad_ang)

			# Build continuous diagonal zigzag nodes: Left -> Center -> Right -> Center -> Left ...
			for i in range(zigzag_count * 2 + 1):
				var level_y = float(i) * step_h
				var step_type = i % 4
				match step_type:
					0: _path_points.append(Vector2(-half_w * dir_mult, level_y)) # Start Wall Node
					1: _path_points.append(Vector2(0.0, level_y))               # Center Node
					2: _path_points.append(Vector2(half_w * dir_mult, level_y))  # Opposite Wall Node
					3: _path_points.append(Vector2(0.0, level_y))               # Center Node
		else:
			# "Stepped (Orthogonal)" - Stepped ladder/zigzag track matching the reference image:
			# Traverses horizontal across, then vertical up/down to next tier, then horizontal across, etc.
			var step_h = zigzag_height
			var curr_x = -half_w * dir_mult
			var curr_y = 0.0
			_path_points.append(Vector2(curr_x, curr_y))

			for i in range(zigzag_count):
				# 1. Horizontal cross to other side
				curr_x = -curr_x
				_path_points.append(Vector2(curr_x, curr_y))

				# 2. Vertical rise/drop to next tier (if not last step)
				if i < zigzag_count - 1:
					curr_y += step_h
					_path_points.append(Vector2(curr_x, curr_y))

		if zigzag_start_from_bottom:
			_path_points.reverse()

	var count = _path_points.size()
	if count >= 2:
		for i in range(count - 1):
			var seg_len = _path_points[i].distance_to(_path_points[i + 1])
			_segment_lengths.append(seg_len)
			_total_path_length += seg_len


func _get_position_at_path_distance(dist_val: float) -> Vector2:
	var count = _path_points.size()
	if count == 0:
		return Vector2.ZERO
	if count == 1 or _total_path_length <= 0.001:
		return _path_points[0]

	var d = dist_val
	if stop_at_end:
		d = clampf(d, 0.0, _total_path_length)
	elif loop_reset:
		d = fposmod(d, _total_path_length)
	else:
		var cycle = _total_path_length * 2.0
		var t_mod = fmod(d, cycle)
		if t_mod < 0.0:
			t_mod += cycle
		if t_mod > _total_path_length:
			d = cycle - t_mod
		else:
			d = t_mod

	var accum = 0.0
	var num_segs = _segment_lengths.size()
	for i in range(num_segs):
		var seg_len = _segment_lengths[i]
		if d <= accum + seg_len or i == num_segs - 1:
			var rem = d - accum
			var t = rem / max(0.001, seg_len)
			t = clampf(t, 0.0, 1.0)
			return _path_points[i].lerp(_path_points[i + 1], t)
		accum += seg_len

	return _path_points[count - 1]


func _get_path_total_forward_time() -> float:
	var count = _path_points.size()
	if count < 2 or _total_path_length <= 0.001:
		return 0.0
	var base_spd = max(1.0, interval_speed if enable_interval_movement else move_speed)
	var num_segs = _segment_lengths.size()
	var forward_duration: float = 0.0
	for i in range(num_segs):
		var travel_t = _segment_lengths[i] / base_spd
		var pause_at_node = get_point_delay(i)
		forward_duration += pause_at_node + travel_t
	var end_pause = get_point_delay(count - 1)
	forward_duration += end_pause
	return forward_duration


func _get_linear_forward_time() -> float:
	var base_spd = max(1.0, interval_speed if enable_interval_movement else move_speed)
	var pos_d = move_dist_pos
	var neg_d = move_dist_neg
	var t_pause = direction_change_delay
	if pos_d > 0.0 and neg_d <= 0.001:
		return pos_d / base_spd
	elif neg_d > 0.0 and pos_d <= 0.001:
		return neg_d / base_spd
	else:
		return (pos_d / base_spd) + t_pause + ((pos_d + neg_d) / base_spd)


func _get_position_at_path_time(t_val: float) -> Vector2:
	var count = _path_points.size()
	if count == 0:
		return Vector2.ZERO
	if count == 1 or _total_path_length <= 0.001:
		return _path_points[0]

	var num_segs = _segment_lengths.size()
	if num_segs == 0:
		return _path_points[0]

	var base_spd = max(1.0, interval_speed if enable_interval_movement else move_speed)

	# Calculate travel times per segment
	var seg_times: Array[float] = []
	var forward_duration: float = 0.0
	for i in range(num_segs):
		var travel_t = _segment_lengths[i] / base_spd
		seg_times.append(travel_t)
		var pause_at_node = get_point_delay(i)
		forward_duration += pause_at_node + travel_t
	var end_pause = get_point_delay(count - 1)
	forward_duration += end_pause

	if forward_duration <= 0.001:
		return _path_points[0]

	var t_cur = t_val
	if stop_at_end:
		t_cur = clampf(t_cur, 0.0, forward_duration)
		return _sample_forward_path(t_cur, seg_times)
	elif loop_reset:
		t_cur = fmod(t_cur, forward_duration)
		if t_cur < 0.0:
			t_cur += forward_duration
		return _sample_forward_path(t_cur, seg_times)
	else:
		# Ping-pong cycle: Forward + Backward
		var backward_duration: float = 0.0
		for i in range(num_segs - 1, -1, -1):
			var travel_t = seg_times[i]
			var pause_at_node = get_point_delay(i + 1)
			backward_duration += pause_at_node + travel_t
		var start_pause = get_point_delay(0)
		backward_duration += start_pause

		var full_cycle = forward_duration + backward_duration
		if full_cycle <= 0.001:
			return _path_points[0]

		var t_mod = fmod(t_cur, full_cycle)
		if t_mod < 0.0:
			t_mod += full_cycle

		if t_mod <= forward_duration:
			return _sample_forward_path(t_mod, seg_times)
		else:
			var t_back = t_mod - forward_duration
			return _sample_backward_path(t_back, seg_times)


func _sample_forward_path(t_pos: float, seg_times: Array[float]) -> Vector2:
	var num_segs = seg_times.size()
	var accum: float = 0.0

	for i in range(num_segs):
		var pause_t = get_point_delay(i)
		# 1. Paused at Point i
		if t_pos < accum + pause_t:
			return _path_points[i]
		accum += pause_t

		# 2. Moving along Segment i to Point i+1
		var travel_t = seg_times[i]
		if t_pos < accum + travel_t:
			var ratio = (t_pos - accum) / maxf(0.0001, travel_t)
			return _path_points[i].lerp(_path_points[i + 1], clampf(ratio, 0.0, 1.0))
		accum += travel_t

	# 3. Paused at end point
	return _path_points[_path_points.size() - 1]


func _sample_backward_path(t_pos: float, seg_times: Array[float]) -> Vector2:
	var num_segs = seg_times.size()
	var accum: float = 0.0

	for i in range(num_segs - 1, -1, -1):
		var pause_t = get_point_delay(i + 1)
		# 1. Paused at Point i+1
		if t_pos < accum + pause_t:
			return _path_points[i + 1]
		accum += pause_t

		# 2. Moving backward along Segment i to Point i
		var travel_t = seg_times[i]
		if t_pos < accum + travel_t:
			var ratio = (t_pos - accum) / maxf(0.0001, travel_t)
			return _path_points[i + 1].lerp(_path_points[i], clampf(ratio, 0.0, 1.0))
		accum += travel_t

	# 3. Paused at start point 0
	return _path_points[0]


func _update_movement_cache() -> void:
	_has_reached_end = false
	_rebuild_path_points()

	if is_zigzag or not custom_waypoints.is_empty():
		_has_movement = has_gear and (_total_path_length > 0.0) and (move_speed > 0.0)
		_update_rod_dimensions()
		_update_gears_positions(0.0)
		return

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

	# Clear previous zigzag segment rods and snake tier rods
	for child in get_children(true):
		if child.name.begins_with("ZigZagRod_") or child.is_in_group("zigzag_rod") or child.name.begins_with("SnakeRod_") or child.is_in_group("snake_rod"):
			child.queue_free()
			remove_child(child)

	if is_zigzag or not custom_waypoints.is_empty():
		if rod_body:
			rod_body.visible = false
			rod_body.process_mode = Node.PROCESS_MODE_DISABLED

		if not show_track_rods and not has_rod:
			return

		var num_segs = _segment_lengths.size()
		var rod_thick = max(breadth, rod_breadth)
		var theme_id = world_theme if world_theme != "" else WorldThemeRegistry.get_current_theme()
		var r_tex = WorldThemeRegistry.get_gear_rod_texture(theme_id)

		for i in range(num_segs):
			var p1 = _path_points[i]
			var p2 = _path_points[i + 1]
			var seg_len = _segment_lengths[i]
			if seg_len <= 0.001:
				continue

			var seg_center = (p1 + p2) * 0.5
			var seg_angle = (p2 - p1).angle()

			var seg_rod := StaticBody2D.new()
			seg_rod.name = "ZigZagRod_%d" % i
			seg_rod.position = seg_center
			seg_rod.rotation = seg_angle
			seg_rod.add_to_group("obstacle")
			seg_rod.add_to_group("zigzag_rod")
			seg_rod.set_meta("is_lethal", rod_is_lethal)

			if rod_has_collision:
				seg_rod.collision_layer = 1 | 4
				seg_rod.collision_mask = 2
			else:
				seg_rod.collision_layer = 0
				seg_rod.collision_mask = 0

			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(seg_len, rod_thick)
			col.shape = shape
			col.disabled = not rod_has_collision
			seg_rod.add_child(col)

			if r_tex:
				var spr := Sprite2D.new()
				spr.texture = r_tex
				spr.rotation = PI * 0.5
				var tex_h = float(r_tex.get_height())
				var tex_w = float(r_tex.get_width())
				if tex_h > 0.0: spr.scale.y = seg_len / tex_h
				if tex_w > 0.0: spr.scale.x = rod_thick / tex_w
				seg_rod.add_child(spr)

			add_child(seg_rod, false, Node.INTERNAL_MODE_BACK)
		return

	if is_snake_wave:
		var total_tiers = maxi(1, snake_gear_count)
		var should_have_rods = (has_rod or snake_show_rods)

		if not should_have_rods or not rod_body:
			if rod_body:
				rod_body.visible = false
				rod_body.process_mode = Node.PROCESS_MODE_DISABLED
				if rod_col:
					rod_col.disabled = true
			return

		var rod_len = max(length, _total_span)
		var rod_center = _move_dir_vec * _center_offset
		var rod_thick = max(breadth, rod_breadth)
		var rad_angle = deg_to_rad(move_angle)

		var theme_id = world_theme if world_theme != "" else WorldThemeRegistry.get_current_theme()
		var r_tex = WorldThemeRegistry.get_gear_rod_texture(theme_id)
		if r_tex == null and rod_sprite and rod_sprite.texture:
			r_tex = rod_sprite.texture

		# Primary Rod (Tier 0)
		rod_body.visible = true
		rod_body.process_mode = Node.PROCESS_MODE_INHERIT
		rod_body.position = rod_center
		rod_body.rotation = rad_angle
		rod_body.add_to_group("obstacle")
		rod_body.set_meta("is_lethal", rod_is_lethal)

		if rod_has_collision:
			rod_body.collision_layer = 1 | 4
			rod_body.collision_mask = 2
		else:
			rod_body.collision_layer = 0
			rod_body.collision_mask = 0

		if rod_col:
			rod_col.disabled = not rod_has_collision
			if not rod_col.shape or not rod_col.shape is RectangleShape2D:
				rod_col.shape = RectangleShape2D.new()
			elif not rod_col.shape.resource_local_to_scene:
				rod_col.shape = rod_col.shape.duplicate()
			(rod_col.shape as RectangleShape2D).size = Vector2(rod_len, rod_thick)

		if rod_sprite:
			if r_tex:
				rod_sprite.texture = r_tex
			rod_sprite.position = Vector2.ZERO
			rod_sprite.rotation = PI * 0.5
			if rod_sprite.texture:
				var tex_h = float(rod_sprite.texture.get_height())
				var tex_w = float(rod_sprite.texture.get_width())
				if tex_h > 0.0: rod_sprite.scale.y = rod_len / tex_h
				if tex_w > 0.0: rod_sprite.scale.x = rod_thick / tex_w

		# Spawn Rods for Tiers 1 .. total_tiers - 1
		for i in range(1, total_tiers):
			var tier_pos = Vector2(float(i) * snake_spacing_x, float(i) * snake_spacing_y) + rod_center
			var snake_rod := StaticBody2D.new()
			snake_rod.name = "SnakeRod_%d" % i
			snake_rod.position = tier_pos
			snake_rod.rotation = rad_angle
			snake_rod.add_to_group("obstacle")
			snake_rod.add_to_group("snake_rod")
			snake_rod.set_meta("is_lethal", rod_is_lethal)

			if rod_has_collision:
				snake_rod.collision_layer = 1 | 4
				snake_rod.collision_mask = 2
			else:
				snake_rod.collision_layer = 0
				snake_rod.collision_mask = 0

			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(rod_len, rod_thick)
			col.shape = shape
			col.disabled = not rod_has_collision
			snake_rod.add_child(col)

			if r_tex:
				var spr := Sprite2D.new()
				spr.texture = r_tex
				spr.rotation = PI * 0.5
				var tex_h = float(r_tex.get_height())
				var tex_w = float(r_tex.get_width())
				if tex_h > 0.0: spr.scale.y = rod_len / tex_h
				if tex_w > 0.0: spr.scale.x = rod_thick / tex_w
				snake_rod.add_child(spr)

			add_child(snake_rod, false, Node.INTERNAL_MODE_BACK)
		return

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
		var max_gear_offset: float = 0.0
		if group_count > 1 and gears_per_group > 0:
			max_gear_offset = float(group_count - 1) * group_spacing + float(gears_per_group - 1) * gear_spacing
		elif gear_count > 1:
			max_gear_offset = float(gear_count - 1) * gear_spacing

		rod_len = max(length, _total_span + max_gear_offset)
		if move_dist_pos > 0.0 and move_dist_neg <= 0.001:
			rod_center = _move_dir_vec * (rod_len * 0.5)
		elif move_dist_neg > 0.0 and move_dist_pos <= 0.001:
			rod_center = -_move_dir_vec * (rod_len * 0.5)
		else:
			rod_center = _move_dir_vec * (_center_offset + max_gear_offset * 0.5)
	else:
		# Static rod barrier centered at node origin
		rod_len = max(length, move_distance)
		rod_center = Vector2.ZERO

	var rod_thick: float = max(breadth, rod_breadth)
	rod_body.position = rod_center
	rod_body.rotation = deg_to_rad(move_angle)

	if rod_body:
		if rod_has_collision:
			rod_body.collision_layer = 1 | 4
			rod_body.collision_mask = 2
		else:
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

func _get_effective_speed_factor(t_raw: float) -> float:
	var spd_factor: float = 1.0
	if enable_interval_movement:
		var cycle: float = interval_move_time + interval_pause_time
		if cycle > 0.001:
			var t_in_cycle: float = fmod(t_raw, cycle)
			if t_in_cycle >= interval_move_time:
				spd_factor = interval_slow_factor

	if enable_speed_modulation:
		var base_spd = interval_speed if enable_interval_movement else move_speed
		var duration = interval_time if (enable_interval_movement and interval_time > 0.0) else max(0.5, _total_span / max(1.0, base_spd))
		var phase = (t_raw / max(0.1, duration)) * speed_pulses_per_interval * TAU
		var wave = 0.5 * (1.0 + sin(phase))
		spd_factor *= lerpf(min_speed_scale, max_speed_scale, wave)

	return spd_factor

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _has_movement and not (has_gear and rotation_speed != 0.0):
		return

	if _has_reached_end:
		if has_gear and rotation_speed != 0.0:
			for spr in _gear_sprites:
				if spr:
					spr.rotation += rotation_speed * delta
		return

	_elapsed_time += delta
	var t_raw = max(0.0, _elapsed_time - start_delay)
	var spd_factor = _get_effective_speed_factor(t_raw)
	var base_spd = interval_speed if enable_interval_movement else move_speed
	var cur_spd = base_spd * spd_factor

	# Spin all gear sprites with speed-proportional rotation
	if has_gear and rotation_speed != 0.0:
		for spr in _gear_sprites:
			if spr:
				spr.rotation += rotation_speed * spd_factor * delta

	# Process movement
	if _has_movement:
		if _elapsed_time < start_delay:
			return

		_motion_accum_time += spd_factor * delta

		if is_zigzag or not custom_waypoints.is_empty():
			if stop_at_end:
				var max_t = _get_path_total_forward_time()
				if _motion_accum_time >= max_t:
					_motion_accum_time = max_t
					_has_reached_end = true
			_update_gears_positions(0.0)
			return

		if loop_reset:
			# Continuous wrap-around along the rod track (respawns cleanly at origin in loop)
			_progress += (base_spd / max(1.0, _total_span)) * spd_factor * delta
			if stop_at_end:
				if _progress >= 1.0:
					_progress = 1.0
					_has_reached_end = true
			else:
				if _progress >= 1.0:
					_progress = fmod(_progress, 1.0)
			_update_gears_positions(0.0)
		else:
			# Ping-pong oscillation with endpoint delays
			if stop_at_end:
				var end_t = _get_linear_forward_time()
				if _motion_accum_time >= end_t:
					_motion_accum_time = end_t
					_has_reached_end = true
			var offset_scalar = _calculate_offset_scalar(_motion_accum_time)
			_update_gears_positions(offset_scalar)

func _calculate_offset_scalar(t_act: float) -> float:
	var base_spd = interval_speed if enable_interval_movement else move_speed
	var pos_d = move_dist_pos
	var neg_d = move_dist_neg
	var t_pause = direction_change_delay

	if pos_d > 0.0 and neg_d <= 0.001:
		var t_one = pos_d / max(1.0, base_spd)
		if stop_at_end:
			if t_act < t_one:
				var s = (1.0 - cos((t_act / max(0.001, t_one)) * PI)) * 0.5
				return pos_d * s
			else:
				return pos_d
		if t_pause > 0.0:
			var cycle = 2.0 * (t_one + t_pause)
			var t = fposmod(t_act, cycle)
			if t < t_one:
				var s = (1.0 - cos((t / t_one) * PI)) * 0.5
				return pos_d * s
			elif t < t_one + t_pause:
				return pos_d
			elif t < 2.0 * t_one + t_pause:
				var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
				return pos_d * (1.0 - s)
			else:
				return 0.0
		else:
			var phase = t_act * (base_spd / max(1.0, pos_d)) * PI
			return pos_d * 0.5 * (1.0 - cos(phase))

	elif neg_d > 0.0 and pos_d <= 0.001:
		var t_one = neg_d / max(1.0, base_spd)
		if stop_at_end:
			if t_act < t_one:
				var s = (1.0 - cos((t_act / max(0.001, t_one)) * PI)) * 0.5
				return -neg_d * s
			else:
				return -neg_d
		if t_pause > 0.0:
			var cycle = 2.0 * (t_one + t_pause)
			var t = fposmod(t_act, cycle)
			if t < t_one:
				var s = (1.0 - cos((t / t_one) * PI)) * 0.5
				return -neg_d * s
			elif t < t_one + t_pause:
				return -neg_d
			elif t < 2.0 * t_one + t_pause:
				var s = (1.0 - cos(((t - (t_one + t_pause)) / t_one) * PI)) * 0.5
				return -neg_d * (1.0 - s)
			else:
				return 0.0
		else:
			var phase = t_act * (base_spd / max(1.0, neg_d)) * PI
			return -neg_d * 0.5 * (1.0 - cos(phase))

	else:
		var t_pos = pos_d / max(1.0, base_spd)
		var t_neg = neg_d / max(1.0, base_spd)
		var t_span = (pos_d + neg_d) / max(1.0, base_spd)
		if stop_at_end:
			if t_act < t_pos:
				var s = sin((t_act / max(0.001, t_pos)) * (PI * 0.5))
				return pos_d * s
			elif t_act < t_pos + t_pause:
				return pos_d
			elif t_act < t_pos + t_pause + t_span:
				var u = t_act - (t_pos + t_pause)
				var s = (1.0 - cos((u / max(0.001, t_span)) * PI)) * 0.5
				return pos_d - (pos_d + neg_d) * s
			else:
				return -neg_d

		var cycle = 2.0 * t_span + 2.0 * t_pause
		var t = fposmod(t_act, cycle)

		if t < t_pos:
			var s = sin((t / max(0.001, t_pos)) * (PI * 0.5))
			return pos_d * s
		elif t < t_pos + t_pause:
			return pos_d
		elif t < t_pos + t_pause + t_span:
			var u = t - (t_pos + t_pause)
			var s = (1.0 - cos((u / max(0.001, t_span)) * PI)) * 0.5
			return pos_d - (pos_d + neg_d) * s
		elif t < t_pos + 2.0 * t_pause + t_span:
			return -neg_d
		else:
			var v = t - (t_pos + 2.0 * t_pause + t_span)
			var s = cos((v / max(0.001, t_neg)) * (PI * 0.5))
			return -neg_d * s

func _update_gears_positions(offset_scalar: float) -> void:
	var count = _gear_bodies.size()
	if count == 0 or not has_gear:
		return

	if is_snake_wave:
		var base_spd = interval_speed if enable_interval_movement else move_speed
		if loop_reset:
			var track_start = -_move_dir_vec * move_dist_neg
			for i in range(count):
				var body = _gear_bodies[i]
				if not body:
					continue
				var t_offset = _get_snake_gear_time_offset(i, count, base_spd)
				var prog_offset = (t_offset * base_spd) / max(1.0, _total_span)
				var gear_prog = fposmod(_progress - prog_offset, 1.0)
				var travel_offset = _move_dir_vec * (gear_prog * _total_span)
				var tier_offset = Vector2(float(i) * snake_spacing_x, float(i) * snake_spacing_y)
				body.position = tier_offset + track_start + travel_offset
		else:
			for i in range(count):
				var body = _gear_bodies[i]
				if not body:
					continue
				var t_offset = _get_snake_gear_time_offset(i, count, base_spd)
				var gear_t = _motion_accum_time - t_offset
				var stagger_scalar = _calculate_offset_scalar(gear_t)
				var travel_offset = _move_dir_vec * stagger_scalar
				var tier_offset = Vector2(float(i) * snake_spacing_x, float(i) * snake_spacing_y)
				body.position = tier_offset + travel_offset
		return

	var has_groups = (group_count > 1 and gears_per_group > 0)

	if is_zigzag or not custom_waypoints.is_empty():
		if _total_path_length <= 0.001:
			return
		var pause_dur = node_pause_time if enable_node_pause else 0.0
		if pause_dur > 0.0:
			var base_spd = max(1.0, interval_speed if enable_interval_movement else move_speed)
			var total_travel_t = _total_path_length / base_spd
			var num_segs = float(_segment_lengths.size())
			var total_cycle_time = total_travel_t + (num_segs * pause_dur)
			
			var spacing_t = gear_spacing / base_spd
			if is_zero_approx(gear_spacing) or gear_spacing == 100.0: # Default fallback or 0 space evenly across path
				spacing_t = total_cycle_time / float(count)

			for i in range(count):
				var body = _gear_bodies[i]
				if not body:
					continue
				var base_offset_t: float = 0.0
				if has_groups:
					var g = i / gears_per_group
					var k = i % gears_per_group
					base_offset_t = (float(g) * group_spacing + float(k) * gear_spacing) / base_spd
				else:
					base_offset_t = float(i) * spacing_t
				var gear_t = _motion_accum_time + base_offset_t
				body.position = _get_position_at_path_time(gear_t)
			return

		var base_spd = interval_speed if enable_interval_movement else move_speed
		var base_dist = _motion_accum_time * base_spd
		var effective_spacing = gear_spacing
		if is_zero_approx(effective_spacing):
			effective_spacing = _total_path_length / float(count)

		for i in range(count):
			var body = _gear_bodies[i]
			if not body:
				continue
			var base_offset: float = 0.0
			if has_groups:
				var g = i / gears_per_group
				var k = i % gears_per_group
				base_offset = float(g) * group_spacing + float(k) * gear_spacing
			else:
				base_offset = float(i) * effective_spacing
			var gear_dist = base_dist + base_offset
			body.position = _get_position_at_path_distance(gear_dist)
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
			var base_dist: float = 0.0
			if has_groups:
				var g = i / gears_per_group
				var k = i % gears_per_group
				base_dist = float(g) * group_spacing + float(k) * gear_spacing
			else:
				base_dist = float(i) * effective_spacing
			var gear_prog: float = 0.0
			if stop_at_end:
				gear_prog = clampf(_progress + (base_dist / max(1.0, _total_span)), 0.0, 1.0)
			else:
				gear_prog = fposmod(_progress + (base_dist / max(1.0, _total_span)), 1.0)
			var travel_offset = gear_prog * _total_span
			body.position = track_start + (_move_dir_vec * travel_offset)
	else:
		for i in range(count):
			var body = _gear_bodies[i]
			if not body:
				continue
			var base_dist: float = 0.0
			var stagger_scalar: float = offset_scalar
			if has_groups:
				var g = i / gears_per_group
				var k = i % gears_per_group
				base_dist = float(g) * group_spacing + float(k) * gear_spacing
				if group_phase_stagger > 0.0:
					var staggered_t = max(0.0, _motion_accum_time - float(g) * group_phase_stagger)
					stagger_scalar = _calculate_offset_scalar(staggered_t)
			else:
				base_dist = float(i) * gear_spacing

			var spacing_offset = _move_dir_vec * base_dist
			body.position = (_move_dir_vec * stagger_scalar) + spacing_offset

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

	if is_zigzag or not custom_waypoints.is_empty():
		var count = _path_points.size()
		if count >= 2:
			var line_col = Color(0.0, 0.9, 1.0, 0.85)
			var node_col = Color(1.0, 0.85, 0.2, 0.95)
			var num_segs = _segment_lengths.size()

			for i in range(num_segs):
				var p1 = _path_points[i]
				var p2 = _path_points[i + 1]
				_draw_dashed_line(p1, p2, line_col, 2.5, 12.0)

			for i in range(count):
				var pt = _path_points[i]
				draw_circle(pt, 6.5, node_col)
				draw_arc(pt, 10.0, 0.0, TAU, 16, Color(1.0, 0.5, 0.1, 0.8), 2.0)
				if font:
					var p_del = get_point_delay(i)
					var p_txt = "P%d" % i
					if p_del > 0.0:
						p_txt += " (%.1fs)" % p_del
					draw_string(font, pt + Vector2(10, 4), p_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 0.4, 0.95))

			if font:
				var pattern_name = zigzag_pattern if is_zigzag else "Custom Waypoints"
				var label_str = "%s: %.0f px (%d Points)" % [pattern_name, _total_path_length, count]
				if stop_at_end:
					label_str += " [Stop at End]"
				elif loop_reset:
					label_str += " [Loop Mode]"
				else:
					label_str += " [Ping-Pong]"
				if gear_count > 1:
					label_str += " | %d Gears" % gear_count
				draw_string(font, _path_points[0] + Vector2(12, -14), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))
		return

	if is_snake_wave and has_gear and _has_movement:
		var total_tiers = maxi(1, snake_gear_count)
		var base_p_neg = -_move_dir_vec * move_dist_neg
		var base_p_pos = _move_dir_vec * move_dist_pos

		var line_col = Color(0.0, 0.9, 1.0, 0.75)
		var end_col = Color(1.0, 0.35, 0.35, 0.95)
		var origin_col = Color(0.2, 1.0, 0.4, 0.95)
		var perp = _move_dir_vec.orthogonal() * 14.0

		for i in range(total_tiers):
			var tier_pos = Vector2(float(i) * snake_spacing_x, float(i) * snake_spacing_y)
			var p_neg = tier_pos + base_p_neg
			var p_pos = tier_pos + base_p_pos

			_draw_dashed_line(p_neg, p_pos, line_col, 2.0, 10.0)
			draw_circle(tier_pos, 4.0, origin_col)

			draw_line(p_neg - perp, p_neg + perp, end_col, 3.0)
			draw_line(p_pos - perp, p_pos + perp, end_col, 3.0)

			if font:
				var label_str = "Distance: %.0f (-%.0f / +%.0f)" % [_total_span, move_dist_neg, move_dist_pos]
				draw_string(font, p_pos + Vector2(10, 4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))

		if font:
			var head_txt = "Snake Wave: %d Gears (Gap Y: %.0f, Delay: %.2fs)" % [snake_gear_count, snake_spacing_y, snake_delay]
			draw_string(font, base_p_neg + Vector2(0, -18), head_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 1.0, 0.6, 0.95))
		return

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

		var has_groups = (group_count > 1 and gears_per_group > 0)
		if has_groups:
			for g in range(group_count):
				for k in range(gears_per_group):
					if g == 0 and k == 0:
						continue
					var g_offset = (float(g) * group_spacing) + (float(k) * gear_spacing)
					var g_pos = _move_dir_vec * g_offset
					draw_circle(g_pos, 4.5, Color(1.0, 0.85, 0.2, 0.9) if k == 0 else Color(0.2, 0.85, 1.0, 0.8))
		elif gear_count > 1:
			for i in range(1, gear_count):
				var g_pos = _move_dir_vec * (float(i) * gear_spacing)
				draw_circle(g_pos, 4.5, Color(1.0, 0.85, 0.2, 0.9))

		if font:
			var label_str = "Distance: %.0f (-%.0f / +%.0f)" % [_total_span, move_dist_neg, move_dist_pos]
			if stop_at_end:
				label_str += " [Stop at End]"
			elif loop_reset:
				label_str += " [Loop Mode]"
			elif direction_change_delay > 0.0 or start_delay > 0.0:
				label_str += " | Delay: %.1fs" % [direction_change_delay + start_delay]
			if has_groups:
				label_str += " | %d Groups (%d gears/grp, Gap: %.0f, Dist: %.0f)" % [group_count, gears_per_group, gear_spacing, group_spacing]
			elif gear_count > 1:
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
