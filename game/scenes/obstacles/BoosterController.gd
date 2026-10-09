@tool
extends Area2D
class_name BoosterController

enum ForceTier {
	TIER_1_LOW = 1,
	TIER_2_MEDIUM = 2,
	TIER_3_HIGH = 3,
	TIER_4_SUPER = 4,
	TIER_5_MEGA = 5,
	TIER_6_ULTRA = 6,
	TIER_7_HYPER = 7,
	TIER_8_EXTREME = 8,
	TIER_9_COLOSSAL = 9,
	TIER_10_HUGE = 10
}

const FORCE_TIERS: Dictionary = {
	ForceTier.TIER_1_LOW: 650.0,
	ForceTier.TIER_2_MEDIUM: 950.0,
	ForceTier.TIER_3_HIGH: 1300.0,
	ForceTier.TIER_4_SUPER: 1700.0,
	ForceTier.TIER_5_MEGA: 2200.0,
	ForceTier.TIER_6_ULTRA: 2800.0,
	ForceTier.TIER_7_HYPER: 3500.0,
	ForceTier.TIER_8_EXTREME: 4300.0,
	ForceTier.TIER_9_COLOSSAL: 5200.0,
	ForceTier.TIER_10_HUGE: 6200.0
}

# ==============================================================================
# 1. EXPORT PROPERTIES
# ==============================================================================

# Force Settings (Common to all boosters)
@export_enum("Tier 1 - Low (650)", "Tier 2 - Medium (950)", "Tier 3 - High (1300)", "Tier 4 - Super (1700)", "Tier 5 - Mega (2200)", "Tier 6 - Ultra (2800)", "Tier 7 - Hyper (3500)", "Tier 8 - Extreme (4300)", "Tier 9 - Colossal (5200)", "Tier 10 - Huge (6200)") var force_tier: int = 2:
	set(v):
		force_tier = clampi(v, 1, 10)
		if Engine.is_editor_hint():
			queue_redraw()

@export var custom_force: float = 0.0:
	set(v):
		custom_force = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var invulnerability_duration: float = 0.6
@export var data: BoosterData

# Multi-Booster System & Rotation Angles
@export_range(1, 20, 1) var booster_count: int = 1:
	set(v):
		booster_count = clampi(v, 1, 20)
		_rebuild_clones()
		if Engine.is_editor_hint():
			queue_redraw()

@export var booster_spacing: float = 120.0:
	set(v):
		booster_spacing = maxf(10.0, v)
		_update_movement_metrics()
		_update_positions(0.0)
		if Engine.is_editor_hint():
			queue_redraw()

## Common facing / launch angle of all boosters in degrees (0° = UP, 90° = RIGHT, 180° = DOWN, -90° = LEFT)
@export var booster_angle: float = 0.0:
	set(v):
		booster_angle = v
		_update_positions(0.0)
		if Engine.is_editor_hint():
			queue_redraw()

## Comma-separated individual angles of rotation for each booster in the train (e.g. "0, 45, 90, 180")
@export var booster_angles_str: String = "":
	set(v):
		booster_angles_str = v
		_parse_booster_angles_str()
		_update_positions(0.0)
		if Engine.is_editor_hint():
			queue_redraw()

var booster_angles: Array = []

func _parse_booster_angles_str() -> void:
	booster_angles.clear()
	if booster_angles_str.strip_edges() == "":
		return
	var parts = booster_angles_str.split(",")
	for p in parts:
		var s = p.strip_edges()
		if s.is_valid_float():
			booster_angles.append(s.to_float())

func get_booster_angle(idx: int) -> float:
	if idx >= 0 and idx < booster_angles.size() and booster_angles[idx] != null:
		return float(booster_angles[idx])
	return booster_angle

# Movement Settings
@export var move_speed: float = 0.0:
	set(v):
		move_speed = maxf(0.0, v)
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_distance: float = 200.0:
	set(v):
		move_distance = maxf(0.0, v)
		if move_dist_pos <= 0.0 and move_dist_neg <= 0.0:
			move_dist_pos = move_distance
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_dist_pos: float = 200.0:
	set(v):
		move_dist_pos = maxf(0.0, v)
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_dist_neg: float = 0.0:
	set(v):
		move_dist_neg = maxf(0.0, v)
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var move_angle: float = 0.0:
	set(v):
		move_angle = v
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export_enum("+X", "-X", "+Y", "-Y", "X", "Y", "Custom") var move_direction: String = "X":
	set(v):
		move_direction = v
		_sync_direction_enum()
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var loop_reset: bool = true:
	set(v):
		loop_reset = v
		_update_movement_metrics()
		if Engine.is_editor_hint():
			queue_redraw()

@export var start_delay: float = 0.0:
	set(v):
		start_delay = maxf(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var direction_change_delay: float = 0.0:
	set(v):
		direction_change_delay = maxf(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

# Backward compatibility alias
var delay: float:
	get: return direction_change_delay
	set(v): direction_change_delay = v

# ==============================================================================
# 2. INTERNAL STATE & NODE REFERENCES
# ==============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var marker: Marker2D = $Marker2D if has_node("Marker2D") else null

var _default_sprite_pos: Vector2 = Vector2(4.5, 0.5)
var _default_col_pos: Vector2 = Vector2(2, 44.25)
var _clone_nodes: Array[Area2D] = []

var _move_dir_vec: Vector2 = Vector2.RIGHT
var _total_span: float = 0.0
var _track_start: Vector2 = Vector2.ZERO
var _has_movement: bool = false
var _elapsed_time: float = 0.0
var _progress: float = 0.0
var _is_boosting: bool = false
var triggered: bool = false

# ==============================================================================
# 3. LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	add_to_group("boosters")
	add_to_group("obstacle")

	collision_layer = 2
	collision_mask = 3  # Detect player on layer 1 & 2

	_ensure_base_references()
	_update_movement_metrics()
	_rebuild_clones()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

	_apply_process_state()

func _ensure_base_references() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if col_shape == null and has_node("CollisionShape2D"):
		col_shape = get_node("CollisionShape2D") as CollisionShape2D
	if marker == null and has_node("Marker2D"):
		marker = get_node("Marker2D") as Marker2D

	if sprite and sprite.texture == null:
		var tex_path = "res://game/assets/sprites/obstacles/Booster.png"
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)

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

func _update_movement_metrics() -> void:
	_move_dir_vec = Vector2.from_angle(deg_to_rad(move_angle))

	if move_dist_pos > 0.0 and move_dist_neg > 0.0:
		_total_span = move_dist_pos + move_dist_neg
		_track_start = -_move_dir_vec * move_dist_neg
	elif move_dist_pos > 0.0:
		_total_span = move_dist_pos
		_track_start = Vector2.ZERO
	elif move_dist_neg > 0.0:
		_total_span = move_dist_neg
		_track_start = -_move_dir_vec * move_dist_neg
	else:
		_total_span = move_distance
		_track_start = Vector2.ZERO

	_has_movement = (move_speed > 0.001 and _total_span > 0.001)
	_apply_process_state()

func _apply_process_state() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		set_process(false)
		set_physics_process(_has_movement)

# ==============================================================================
# 4. CLONE SPAWNING & POSITIONING
# ==============================================================================

func _rebuild_clones() -> void:
	_ensure_base_references()

	# Clear previous clones
	for child in get_children(true):
		if child != sprite and child != col_shape and child != marker:
			if child.name.begins_with("BoosterClone_") or child.is_in_group("booster_clone"):
				child.queue_free()
				remove_child(child)

	_clone_nodes.clear()

	var target_count = maxi(1, booster_count)
	for i in range(1, target_count):
		var clone := Area2D.new()
		clone.name = "BoosterClone_%d" % i
		clone.collision_layer = collision_layer
		clone.collision_mask = collision_mask
		clone.add_to_group("boosters")
		clone.add_to_group("obstacle")
		clone.add_to_group("booster_clone")

		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		spr.position = _default_sprite_pos
		spr.scale = Vector2(0.2, 0.2)
		if sprite and sprite.texture:
			spr.texture = sprite.texture
		else:
			var tex_path = "res://game/assets/sprites/obstacles/Booster.png"
			if ResourceLoader.exists(tex_path):
				spr.texture = load(tex_path)
		clone.add_child(spr)

		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		col.position = _default_col_pos
		var rect := RectangleShape2D.new()
		rect.size = Vector2(82, 26.5)
		col.shape = rect
		clone.add_child(col)

		if not Engine.is_editor_hint():
			clone.body_entered.connect(_on_clone_body_entered.bind(clone))

		# Node.INTERNAL_MODE_BACK guarantees clones are never saved to scene files
		add_child(clone, false, Node.INTERNAL_MODE_BACK)
		_clone_nodes.append(clone)

	_update_positions(0.0)

func _update_positions(offset_scalar: float) -> void:
	var rad_0 = deg_to_rad(get_booster_angle(0))

	if not _has_movement:
		# Static placement along local direction
		if sprite:
			sprite.position = _default_sprite_pos.rotated(rad_0)
			sprite.rotation = rad_0
		if col_shape:
			col_shape.position = _default_col_pos.rotated(rad_0)
			col_shape.rotation = rad_0

		for i in range(_clone_nodes.size()):
			var clone = _clone_nodes[i]
			if clone:
				var rad_i = deg_to_rad(get_booster_angle(i + 1))
				var clone_offset = _move_dir_vec * (float(i + 1) * booster_spacing)
				clone.position = clone_offset
				clone.rotation = rad_i
		return

	if loop_reset:
		var track_len = maxf(1.0, _total_span)
		# Primary booster (index 0)
		var prog_0 = fposmod(_progress, 1.0)
		var pos_0 = _track_start + _move_dir_vec * (prog_0 * track_len)
		if sprite:
			sprite.position = pos_0 + _default_sprite_pos.rotated(rad_0)
			sprite.rotation = rad_0
		if col_shape:
			col_shape.position = pos_0 + _default_col_pos.rotated(rad_0)
			col_shape.rotation = rad_0

		# Clone boosters (index 1..N-1)
		for i in range(_clone_nodes.size()):
			var clone = _clone_nodes[i]
			if clone:
				var rad_i = deg_to_rad(get_booster_angle(i + 1))
				var base_dist = float(i + 1) * booster_spacing
				var prog_i = fposmod(_progress + (base_dist / track_len), 1.0)
				var pos_i = _track_start + _move_dir_vec * (prog_i * track_len)
				clone.position = pos_i
				clone.rotation = rad_i
	else:
		# Ping-pong oscillation
		var pos_0 = _track_start + _move_dir_vec * offset_scalar
		if sprite:
			sprite.position = pos_0 + _default_sprite_pos.rotated(rad_0)
			sprite.rotation = rad_0
		if col_shape:
			col_shape.position = pos_0 + _default_col_pos.rotated(rad_0)
			col_shape.rotation = rad_0

		for i in range(_clone_nodes.size()):
			var clone = _clone_nodes[i]
			if clone:
				var rad_i = deg_to_rad(get_booster_angle(i + 1))
				var pos_i = _track_start + _move_dir_vec * (offset_scalar + float(i + 1) * booster_spacing)
				clone.position = pos_i
				clone.rotation = rad_i

# ==============================================================================
# 5. PHYSICS PROCESS & MOVEMENT
# ==============================================================================

func _calculate_offset_scalar(t_act: float) -> float:
	var base_spd = maxf(1.0, move_speed)
	var pos_d = move_dist_pos
	var neg_d = move_dist_neg
	var t_pause = direction_change_delay

	if pos_d > 0.0 and neg_d <= 0.001:
		var t_one = pos_d / base_spd
		if t_pause > 0.0:
			var cycle = 2.0 * (t_one + t_pause)
			var t = fmod(t_act, cycle)
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
			var phase = t_act * (base_spd / maxf(1.0, pos_d)) * PI
			return pos_d * 0.5 * (1.0 - cos(phase))

	elif neg_d > 0.0 and pos_d <= 0.001:
		var t_one = neg_d / base_spd
		if t_pause > 0.0:
			var cycle = 2.0 * (t_one + t_pause)
			var t = fmod(t_act, cycle)
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
			var phase = t_act * (base_spd / maxf(1.0, neg_d)) * PI
			return -neg_d * 0.5 * (1.0 - cos(phase))

	else:
		var t_pos = pos_d / base_spd
		var t_neg = neg_d / base_spd
		var t_span = (pos_d + neg_d) / base_spd
		var cycle = 2.0 * t_span + 2.0 * t_pause
		var t = fmod(t_act, cycle)

		if t < t_pos:
			var s = sin((t / maxf(0.001, t_pos)) * (PI * 0.5))
			return pos_d * s
		elif t < t_pos + t_pause:
			return pos_d
		elif t < t_pos + t_pause + t_span:
			var u = t - (t_pos + t_pause)
			var s = (1.0 - cos((u / maxf(0.001, t_span)) * PI)) * 0.5
			return pos_d - (pos_d + neg_d) * s
		elif t < t_pos + 2.0 * t_pause + t_span:
			return -neg_d
		else:
			var v = t - (t_pos + 2.0 * t_pause + t_span)
			var s = cos((v / maxf(0.001, t_neg)) * (PI * 0.5))
			return -neg_d * s

func _physics_process(delta: float) -> void:
	if not _has_movement or move_speed <= 0.001:
		return

	_elapsed_time += delta
	if _elapsed_time < start_delay:
		return

	var t_act = _elapsed_time - start_delay
	var track_len = maxf(1.0, _total_span)

	if loop_reset:
		_progress += (move_speed * delta) / track_len
		_progress = fposmod(_progress, 1.0)
		_update_positions(0.0)
	else:
		var offset_scalar = _calculate_offset_scalar(t_act)
		_update_positions(offset_scalar)

# ==============================================================================
# 6. BOOST EXECUTION & COLLISION LOGIC
# ==============================================================================

func get_boost_force() -> float:
	if custom_force > 0.0:
		return custom_force
	return FORCE_TIERS.get(force_tier, 950.0)

func get_push_direction() -> Vector2:
	var rad = deg_to_rad(get_booster_angle(0))
	return Vector2.UP.rotated(global_rotation + rad).normalized()

func _on_body_entered(body: Node2D) -> void:
	_trigger_boost_for_node(body, self)

func _on_clone_body_entered(body: Node2D, clone_node: Area2D) -> void:
	_trigger_boost_for_node(body, clone_node)

func _trigger_boost_for_node(body: Node2D, source: Area2D) -> void:
	if _is_boosting:
		return

	var is_player = body is Player \
		or body.is_in_group("player") \
		or body.name.begins_with("Player") \
		or (body is CharacterBody2D and body.has_method("die"))

	if not is_player:
		return

	_is_boosting = true
	var tree: SceneTree = get_tree() if is_inside_tree() else (body.get_tree() if body.is_inside_tree() else null)
	if tree:
		tree.create_timer(0.2).timeout.connect(func(): _is_boosting = false)
	else:
		_is_boosting = false

	var idx = 0
	if source != self:
		var found_idx = _clone_nodes.find(source)
		if found_idx != -1:
			idx = found_idx + 1

	var b_ang_rad = deg_to_rad(get_booster_angle(idx))
	var boost_rot: float = global_rotation + b_ang_rad
	var push_dir: Vector2 = Vector2.UP.rotated(boost_rot).normalized()
	var force: float = get_boost_force()

	# 1. Snap player directly into middle centerline of the touched booster
	body.rotation = boost_rot
	if "visual" in body and body.visual:
		body.visual.rotation = 0.0

	var tangent: Vector2 = Vector2.RIGHT.rotated(boost_rot)
	var center_point: Vector2 = source.global_position
	var col = source.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		center_point = col.global_position

	var to_player: Vector2 = body.global_position - center_point
	var lateral_offset: float = to_player.dot(tangent)
	body.global_position -= tangent * lateral_offset

	# Position slightly along launch direction to ensure clean takeoff
	body.global_position += push_dir * 12.0

	# 2. Launch player with unified force and invulnerability
	if body.has_method("apply_directional_boost"):
		body.apply_directional_boost(push_dir, force, invulnerability_duration, boost_rot)
	elif body.has_method("apply_booster") and data:
		body.apply_booster(data)
	else:
		if "velocity" in body:
			body.velocity = push_dir * force
		if "is_invulnerable" in body:
			body.is_invulnerable = true
		if "_input_lock" in body:
			body.set("_input_lock", invulnerability_duration)

func reset() -> void:
	triggered = false
	_is_boosting = false
	visible = true
	monitoring = true

# ==============================================================================
# 7. IN-EDITOR DRAWING & GUIDELINES
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
	var arrow_len = 45.0 + float(force_tier) * 8.0

	# 1. Draw Movement Guidelines if movement configured
	if _has_movement:
		var p_start = _track_start
		var p_end = _track_start + _move_dir_vec * _total_span
		var line_col = Color(0.0, 0.9, 1.0, 0.85)
		var end_col = Color(1.0, 0.35, 0.35, 0.95)
		var origin_col = Color(0.2, 1.0, 0.4, 0.95)

		_draw_dashed_line(p_start, p_end, line_col, 2.5, 12.0)
		draw_circle(Vector2.ZERO, 5.0, origin_col)

		var perp = _move_dir_vec.orthogonal() * 14.0
		draw_line(p_start - perp, p_start + perp, end_col, 3.0)
		draw_line(p_end - perp, p_end + perp, end_col, 3.0)

	# 2. Draw preview arrows for all boosters in the train
	var total_count = maxi(1, booster_count)
	for i in range(total_count):
		var b_pos = Vector2.ZERO
		if _has_movement:
			if loop_reset:
				var base_dist = float(i) * booster_spacing
				var prog_i = fposmod((base_dist / maxf(1.0, _total_span)), 1.0)
				b_pos = _track_start + _move_dir_vec * (prog_i * _total_span)
			else:
				b_pos = _track_start + _move_dir_vec * (float(i) * booster_spacing)
		else:
			b_pos = _move_dir_vec * (float(i) * booster_spacing)

		var b_ang_rad = deg_to_rad(get_booster_angle(i))
		var launch_dir = Vector2.UP.rotated(b_ang_rad)
		var perp_dir = Vector2.RIGHT.rotated(b_ang_rad)
		var tip = b_pos + launch_dir * arrow_len
		var arrow_col = Color(0.2, 1.0, 0.4, 0.9) if i == 0 else Color(1.0, 0.85, 0.2, 0.85)

		# Draw launch arrow
		draw_line(b_pos, tip, arrow_col, 2.5)
		draw_line(tip, tip - launch_dir * 10.0 - perp_dir * 7.0, arrow_col, 2.5)
		draw_line(tip, tip - launch_dir * 10.0 + perp_dir * 7.0, arrow_col, 2.5)

		# Draw booster pad bar preview
		draw_line(b_pos - perp_dir * 16.0, b_pos + perp_dir * 16.0, Color(arrow_col.r, arrow_col.g, arrow_col.b, 0.5), 4.0)

		if i > 0:
			draw_circle(b_pos, 4.0, arrow_col)

	# 3. Draw HUD Label
	if font:
		var txt = "T%d (%.0f)" % [force_tier, get_boost_force()]
		if booster_count > 1:
			txt += " | %d Boosters (Gap: %.0f)" % [booster_count, booster_spacing]
		if booster_angle != 0.0 or not booster_angles_str.is_empty():
			txt += " | Ang: %.0f°" % booster_angle
		if _has_movement:
			txt += " | Spd: %.0f" % move_speed
			if loop_reset:
				txt += " [Loop]"
			else:
				txt += " [Ping-Pong]"
		draw_string(font, Vector2(-40, -arrow_len - 10), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.95))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width_val: float, dash_len: float = 12.0) -> void:
	var diff = to - from
	var dist = diff.length()
	if dist <= 0.001:
		return
	var dir = diff / dist
	var curr = 0.0
	while curr < dist:
		var next_p = minf(curr + dash_len, dist)
		draw_line(from + dir * curr, from + dir * next_p, color, width_val)
		curr += dash_len * 2.0
