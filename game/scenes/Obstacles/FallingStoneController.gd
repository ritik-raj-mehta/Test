@tool
extends CharacterBody2D
class_name FallingStoneController

@export var is_lethal: bool = false:
	set(v):
		is_lethal = v
		_update_type_and_visuals()

@export var trigger_tag: String = "trap_1":
	set(v):
		trigger_tag = v
		if Engine.is_editor_hint():
			queue_redraw()

@export var fall_speed: float = 1200.0:
	set(v):
		fall_speed = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var gravity: float = 2200.0
@export var rotation_speed: float = 6.0
@export var fall_distance: float = 3500.0:
	set(v):
		fall_distance = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var knockback_force: float = 650.0

@export var rest_lifetime: float = 2.0:
	set(v):
		rest_lifetime = max(0.1, v)

@export var fade_duration: float = 0.4:
	set(v):
		fade_duration = max(0.05, v)

@export var trigger_cooldown: float = 0.6:
	set(v):
		trigger_cooldown = max(0.0, v)

@export_group("Initial Launch")
@export_range(-180.0, 180.0, 1.0) var initial_launch_angle: float = 90.0:
	set(v):
		initial_launch_angle = v
		if Engine.is_editor_hint():
			queue_redraw()

@export var initial_launch_force: float = 1200.0:
	set(v):
		initial_launch_force = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

var is_clone: bool = false
var is_falling: bool = false
var is_resting: bool = false
var is_fading: bool = false
var has_fallen: bool = false
var has_hit_player: bool = false
var has_landed: bool = false
var _rest_timer: float = 0.0
var _hit_cooldown: float = 0.0
var _fall_duration: float = 0.0
var _last_trigger_time: float = -9999.0
var start_pos: Vector2 = Vector2.ZERO
var initial_rotation: float = 0.0
var _active_clones: Array = []

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func get_initial_launch_vector() -> Vector2:
	var dir := Vector2.RIGHT.rotated(deg_to_rad(initial_launch_angle))
	var spd := initial_launch_force if initial_launch_force > 0.0 else fall_speed
	return dir * spd


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	if not is_clone:
		if not is_in_group("falling_stone"):
			add_to_group("falling_stone")
		if not is_in_group("triggerable"):
			add_to_group("triggerable")

	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if col_shape == null and has_node("CollisionShape2D"):
		col_shape = get_node("CollisionShape2D") as CollisionShape2D

	if start_pos == Vector2.ZERO:
		start_pos = global_position
	if sprite and initial_rotation == 0.0:
		initial_rotation = sprite.rotation

	# Collision setup: Layer 2 (Obstacle), Mask 1 (Terrain only)
	collision_layer = 2
	collision_mask = 1

	_setup_hitbox()
	_update_type_and_visuals()

	if not is_clone:
		is_falling = false
		is_resting = false
		is_fading = false
		_last_trigger_time = -9999.0
		modulate.a = 1.0

		if is_in_editor():
			visible = true
			if col_shape:
				col_shape.disabled = false
		else:
			# In gameplay, hide stone and disable collisions until player crosses the trigger area
			visible = false
			if col_shape:
				col_shape.disabled = true

		set_physics_process(false)


func _setup_hitbox() -> void:
	var hitbox := get_node_or_null("PlayerHitbox") as Area2D
	if hitbox == null:
		hitbox = Area2D.new()
		hitbox.name = "PlayerHitbox"
		hitbox.collision_layer = 0
		hitbox.collision_mask = 2
		var hit_shape := CollisionShape2D.new()
		hit_shape.name = "HitShape"
		hitbox.add_child(hit_shape)
		add_child(hitbox)

	if not hitbox.body_entered.is_connected(_on_player_hitbox_body_entered):
		hitbox.body_entered.connect(_on_player_hitbox_body_entered)


func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if not body or body == self or body is FallingStoneController:
		return
	var is_player = (body is CharacterBody2D and (body.name.begins_with("Player") or body is Player)) \
		or body.is_in_group("player") \
		or body.has_method("apply_knockback") \
		or (body.has_method("die") and not (body is FallingStoneController))

	if is_player and not has_hit_player:
		_handle_player_collision(body)


func update_components() -> void:
	start_pos = global_position
	if sprite:
		initial_rotation = sprite.rotation
	_update_type_and_visuals()


func _update_type_and_visuals() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if col_shape == null and has_node("CollisionShape2D"):
		col_shape = get_node("CollisionShape2D") as CollisionShape2D

	if is_lethal:
		if not is_in_group("obstacle"):
			add_to_group("obstacle")
	else:
		if is_in_group("obstacle"):
			remove_from_group("obstacle")

	set_meta("is_lethal", is_lethal)

	_apply_theme()

	# Match collision shape and radius exactly to the sprite image dimensions
	if col_shape:
		col_shape.position = Vector2.ZERO
		if not col_shape.shape or not col_shape.shape is CircleShape2D:
			col_shape.shape = CircleShape2D.new()
		elif not col_shape.shape.resource_local_to_scene:
			col_shape.shape = col_shape.shape.duplicate()

		var target_radius: float = 25.0
		if sprite and sprite.texture:
			sprite.position = Vector2.ZERO
			sprite.offset = Vector2.ZERO
			var t_size: Vector2 = sprite.texture.get_size()
			var r: float = minf(t_size.x * 0.5, t_size.y * 0.5) * 0.5
			if r > 10.0:
				target_radius = r
		elif is_lethal:
			target_radius = 35.0

		(col_shape.shape as CircleShape2D).radius = target_radius

		var hit_shape := get_node_or_null("PlayerHitbox/HitShape") as CollisionShape2D
		if hit_shape:
			hit_shape.shape = col_shape.shape

	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Handle resting state: ONLY valid while resting on solid ground
	if is_resting:
		# If ground was removed or stone somehow isn't on floor, resume falling
		if not is_on_floor():
			is_resting = false
			is_falling = true
			_rest_timer = 0.0
		else:
			_rest_timer += delta
			if _rest_timer >= rest_lifetime:
				is_resting = false
				is_fading = true
			return

	# Handle smooth fading out
	if is_fading:
		# If stone is still in the air while fading, gravity continues pulling it down
		if not is_on_floor():
			velocity.y = minf(2800.0, velocity.y + gravity * delta)
			move_and_slide()

		var fade_step: float = delta / maxf(fade_duration, 0.05)
		modulate.a = maxf(modulate.a - fade_step, 0.0)
		if modulate.a <= 0.0:
			is_fading = false
			if is_clone:
				queue_free()
				return
			visible = false
			modulate.a = 1.0
			if col_shape:
				col_shape.set_deferred("disabled", true)
			set_physics_process(false)
		return

	if not is_falling:
		return

	_fall_duration += delta

	# Check if standing/landing on a slope or floor
	var floor_norm := get_floor_normal()
	var on_slope := is_on_floor() and absf(floor_norm.x) > 0.08 and floor_norm.y < -0.2

	if on_slope:
		# Slope Rolling Physics:
		# Calculate slope tangent vector pointing DOWNHILL along slope surface
		var slope_tangent := Vector2(floor_norm.y, -floor_norm.x)
		if slope_tangent.y < 0.0:
			slope_tangent = -slope_tangent

		# Gravity component parallel to slope surface
		var slope_accel: float = gravity * slope_tangent.y
		velocity += slope_tangent * (slope_accel * delta)

		# Terminal rolling speed clamp along slope
		if velocity.length() > 1400.0:
			velocity = velocity.normalized() * 1400.0

		# Synchronize sprite rotation speed with linear rolling speed along surface (v = w * r)
		var target_roll_speed: float = (velocity.x / 30.0) * 4.0
		rotation_speed = lerpf(rotation_speed, target_roll_speed, 10.0 * delta)
		has_landed = false
	elif is_on_floor():
		# Flat ground friction deceleration
		velocity.y = 0.0
		if absf(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 750.0 * delta)
		rotation_speed = move_toward(rotation_speed, 0.0, 10.0 * delta)
	else:
		# IN THE AIR: Gravity ALWAYS applies! Never stop in mid-air.
		velocity.y = minf(2800.0, velocity.y + gravity * delta)
		if absf(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)

	if sprite:
		sprite.rotation += rotation_speed * delta

	# Cooldown for player re-hit after rebound
	if _hit_cooldown > 0.0:
		_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
		if _hit_cooldown <= 0.0 and velocity.y > 60.0:
			has_hit_player = false

	if is_inside_tree():
		# Maintain floor snapping and up vector for smooth slope rolling
		up_direction = Vector2.UP
		floor_stop_on_slope = false
		floor_max_angle = deg_to_rad(75.0)
		move_and_slide()

		# Process collisions with Terrain and Player
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if not collider:
				continue

			var is_player = (collider is CharacterBody2D and (collider.name.begins_with("Player") or collider is Player)) \
				or collider.is_in_group("player") \
				or collider.has_method("apply_knockback") \
				or (collider.has_method("die") and not (collider is FallingStoneController))

			if is_player:
				if not has_hit_player:
					_handle_player_collision(collider, col)
					break
			else:
				var col_norm := col.get_normal()
				# Check if collision surface is inclined slope or floor
				if col_norm.y < -0.2:
					if absf(col_norm.x) > 0.08:
						# Slope hit: start rolling down slope
						has_landed = false
						var slope_tangent := Vector2(col_norm.y, -col_norm.x)
						if slope_tangent.y < 0.0: slope_tangent = -slope_tangent
						velocity += slope_tangent * 80.0
					else:
						# Flat floor hit
						if velocity.y > 200.0:
							velocity.y = -velocity.y * 0.15
							velocity.x *= 0.7
						else:
							velocity.y = 0.0
							velocity.x = move_toward(velocity.x, 0.0, 750.0 * delta)
							rotation_speed = move_toward(rotation_speed, 0.0, 10.0 * delta)
					break
				elif absf(col_norm.x) > 0.6 and col_norm.y > -0.2:
					# Vertical wall collision: bounce off wall in opposite direction and keep falling/rolling
					velocity.x = -velocity.x * 0.6
					rotation_speed = -rotation_speed * 0.7
					global_position += col_norm * 2.0
				elif col_norm.y > 0.6:
					# Ceiling collision: bounce down
					velocity.y = absf(velocity.y) * 0.5

	# Stone ONLY stops and rests IF it is physically ON REAL GROUND (terrain) and not moving
	if is_on_floor() and not on_slope and _is_real_ground() and velocity.length_squared() < 10.0:
		is_falling = false
		is_resting = true
		velocity = Vector2.ZERO
		rotation_speed = 0.0
		has_landed = true
		_rest_timer = 0.0

	# If stone falls excessively far below map without touching floor, fade out while still falling (never stop in air!)
	if start_pos != Vector2.ZERO and global_position.y > start_pos.y + fall_distance:
		is_falling = false
		is_fading = true


func _is_real_ground() -> bool:
	if not is_on_floor():
		return false
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if not collider:
			continue
		if collider is TileMapLayer or collider is WallsController:
			return true
		if collider is FallingStoneController or (collider.is_in_group("obstacle") and not (collider is WallsController)) or collider.is_in_group("falling_stone"):
			return false
	return true


func _handle_player_collision(player_node: Node2D, collision: KinematicCollision2D = null) -> void:
	if has_hit_player:
		return

	if is_lethal:
		# LETHAL (Spike Stone): Kills player on contact, enters resting state
		has_hit_player = true
		is_falling = false
		is_resting = true
		is_fading = false
		_rest_timer = 0.0
		velocity = Vector2.ZERO

		if player_node.has_method("die") and not player_node.get("is_invulnerable"):
			player_node.die()
		elif player_node.has_method("game_over"):
			player_node.game_over()
	else:
		# NON-LETHAL (Normal Falling Stone):
		# Player gets knocked back cleanly using physics velocity; stone DOES NOT stop or bounce back!
		has_hit_player = true
		_hit_cooldown = 0.4

		var p_pos := player_node.global_position
		# Push player away horizontally and slightly upward to avoid pushing into floor/walls
		var side := 1.0 if (p_pos.x >= global_position.x) else -1.0
		var push_dir := Vector2(side * 0.9, -0.35).normalized()

		# Controlled knockback force that respects collision boundaries
		var impulse_strength: float = clampf(knockback_force, 250.0, 500.0)
		var p_impulse: Vector2 = push_dir * impulse_strength

		if player_node.has_method("apply_knockback"):
			player_node.apply_knockback(p_impulse)
		elif "velocity" in player_node:
			player_node.set("velocity", p_impulse)

		if "_input_lock" in player_node:
			player_node.set("_input_lock", 0.15)

		# STONE DOES NOT STOP OR REBOUND! It maintains full momentum & trajectory
		has_landed = false
		_rest_timer = 0.0


## Called by TriggerArea when player touches the trigger zone
func trigger() -> void:
	if is_clone:
		return

	# Cooling period check: prevent excessive spam if player crosses trigger repeatedly in rapid succession
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_trigger_time < trigger_cooldown:
		return
	_last_trigger_time = current_time

	# If the main stone is currently active on screen (falling, rolling, resting, or fading),
	# do not hide or teleport it! Spawn a new independent stone so each stone finishes its natural lifecycle.
	if is_falling or is_resting or is_fading:
		_spawn_clone_stone()
		return

	_launch_stone()


func _spawn_clone_stone() -> void:
	var valid_clones: Array = []
	for c in _active_clones:
		if is_instance_valid(c):
			valid_clones.append(c)
	_active_clones = valid_clones

	var clone = duplicate() as FallingStoneController
	if not clone:
		return

	clone.is_clone = true
	clone.trigger_tag = ""
	clone.start_pos = start_pos
	clone.initial_rotation = initial_rotation
	clone.global_position = start_pos
	clone.rotation = rotation

	get_parent().add_child(clone)
	if clone.sprite:
		clone.sprite.rotation = initial_rotation

	_active_clones.append(clone)
	clone._launch_stone()


func _launch_stone() -> void:
	modulate.a = 1.0
	if start_pos != Vector2.ZERO:
		global_position = start_pos
	elif is_inside_tree():
		start_pos = global_position

	if sprite:
		sprite.rotation = initial_rotation

	visible = true
	is_falling = true
	is_resting = false
	is_fading = false
	has_fallen = false
	has_hit_player = false
	has_landed = false
	_rest_timer = 0.0
	_hit_cooldown = 0.0
	_fall_duration = 0.0

	if col_shape:
		col_shape.set_deferred("disabled", false)
	set_physics_process(true)

	# Launch stone in configured initial direction and force
	velocity = get_initial_launch_vector()
	if absf(velocity.x) > 10.0:
		rotation_speed = (velocity.x / 40.0)
	else:
		rotation_speed = 6.0

	_play_spawn_effect()


## Spawns an attractive visual burst of shockwave & rock sparks at launch position
func _play_spawn_effect() -> void:
	if Engine.is_editor_hint():
		return

	# 1. Juicy Sprite Pop & Brightness Flash
	if sprite:
		var target_scale: Vector2 = Vector2(0.5, 0.5)
		sprite.scale = target_scale * 0.25
		var pop_tween := create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(sprite, "scale", target_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var flash_color := Color(1.8, 1.5, 1.2, 1.0) if is_lethal else Color(1.6, 1.7, 1.9, 1.0)
		sprite.modulate = flash_color
		pop_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Dynamic Shockwave & Shard Burst Effect
	var parent_node := get_parent()
	if parent_node:
		var burst := StoneSpawnBurst.new()
		burst.is_lethal_theme = is_lethal
		burst.launch_dir = velocity.normalized() if velocity != Vector2.ZERO else Vector2.DOWN
		burst.global_position = global_position
		parent_node.add_child(burst)


## Visual particle & shockwave burst effect on spawn
class StoneSpawnBurst extends Node2D:
	var elapsed: float = 0.0
	var duration: float = 0.35
	var particles: Array = []
	var is_lethal_theme: bool = false
	var launch_dir: Vector2 = Vector2.DOWN

	func _ready() -> void:
		z_index = 25
		for i in range(8):
			var angle := randf_range(0.0, TAU)
			var spd := randf_range(80.0, 240.0)
			var col: Color = Color(1.0, 0.75, 0.3, 0.95) if is_lethal_theme else Color(0.88, 0.82, 0.75, 0.95)
			if randf() > 0.6:
				col = Color(1.0, 1.0, 1.0, 0.95)
			particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * spd + launch_dir * 70.0,
				"size": randf_range(3.0, 6.0),
				"color": col
			})

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= duration:
			queue_free()
			return
		for p in particles:
			p.pos += p.vel * delta
			p.vel *= (1.0 - 5.0 * delta)
		queue_redraw()

	func _draw() -> void:
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var alpha := 1.0 - progress

		# Expanding shockwave ring
		var ring_radius := lerpf(8.0, 42.0, sqrt(progress))
		var ring_col := Color(1.0, 0.8, 0.4, alpha * 0.8) if is_lethal_theme else Color(0.9, 0.92, 1.0, alpha * 0.75)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 24, ring_col, 2.5 * alpha, true)

		# Small soft central puff
		if progress < 0.6:
			var puff_alpha := (1.0 - progress / 0.6) * 0.5
			draw_circle(Vector2.ZERO, lerpf(6.0, 22.0, progress), Color(1.0, 1.0, 1.0, puff_alpha))

		# Flying debris shards
		for p in particles:
			var p_col: Color = p.color
			p_col.a *= alpha
			var current_size: float = p.size * (1.0 - progress * 0.45)
			draw_circle(p.pos, current_size, p_col)


## Reset stone state when player dies/respawns or level restarts
func reset() -> void:
	for clone in _active_clones:
		if is_instance_valid(clone):
			clone.queue_free()
	_active_clones.clear()

	is_falling = false
	is_resting = false
	is_fading = false
	has_fallen = false
	has_hit_player = false
	has_landed = false
	_rest_timer = 0.0
	_hit_cooldown = 0.0
	_last_trigger_time = -9999.0
	velocity = Vector2.ZERO
	if start_pos != Vector2.ZERO:
		global_position = start_pos
	if sprite:
		sprite.rotation = initial_rotation

	modulate.a = 1.0
	if is_in_editor():
		visible = true
		if col_shape:
			col_shape.disabled = false
	else:
		# In gameplay, hide stone and disable collisions on reset
		visible = false
		if col_shape:
			col_shape.disabled = true
	set_physics_process(false)


func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()


func _apply_theme() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if not sprite:
		return

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	var tex: Texture2D = null
	if is_lethal:
		tex = WorldThemeRegistry.get_falling_stone_spike_texture(theme_id)
	else:
		tex = WorldThemeRegistry.get_falling_stone_texture(theme_id)

	if tex:
		sprite.texture = tex


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

	var line_len = min(fall_distance, 350.0)
	var col = Color(1.0, 0.3, 0.3, 0.8) if is_lethal else Color(1.0, 0.75, 0.2, 0.8)
	draw_line(Vector2.ZERO, Vector2(0, line_len), Color(col.r, col.g, col.b, 0.3), 1.5)
	draw_circle(Vector2(0, line_len), 3.0, Color(col.r, col.g, col.b, 0.3))

	# Draw Initial Launch Direction Arrow
	var launch_vec := get_initial_launch_vector()
	if launch_vec != Vector2.ZERO:
		var arrow_dir := launch_vec.normalized()
		var arrow_len := minf(launch_vec.length() * 0.1, 100.0)
		var arrow_end := arrow_dir * maxf(arrow_len, 40.0)
		draw_line(Vector2.ZERO, arrow_end, col, 3.0)
		var side1 := arrow_end - arrow_dir.rotated(deg_to_rad(30.0)) * 12.0
		var side2 := arrow_end - arrow_dir.rotated(deg_to_rad(-30.0)) * 12.0
		draw_line(arrow_end, side1, col, 3.0)
		draw_line(arrow_end, side2, col, 3.0)

	var font = ThemeDB.fallback_font
	if font:
		var type_str = "Spike Stone" if is_lethal else "Falling Stone"
		var label_str = "%s [%s]" % [type_str, trigger_tag]
		draw_string(font, Vector2(12, -4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))
