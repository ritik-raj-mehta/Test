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

@export var fall_speed: float = 600.0:
	set(v):
		fall_speed = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var gravity: float = 1200.0
@export var rotation_speed: float = 4.0
@export var fall_distance: float = 3000.0:
	set(v):
		fall_distance = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var knockback_force: float = 600.0
@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

var is_falling: bool = false
var has_fallen: bool = false
var has_hit_player: bool = false
var has_landed: bool = false
var _rest_timer: float = 0.0
var _hit_cooldown: float = 0.0
var start_pos: Vector2 = Vector2.ZERO
var initial_rotation: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	if not is_in_group("falling_stone"):
		add_to_group("falling_stone")
	if not is_in_group("triggerable"):
		add_to_group("triggerable")

	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if col_shape == null and has_node("CollisionShape2D"):
		col_shape = get_node("CollisionShape2D") as CollisionShape2D

	start_pos = global_position
	if sprite:
		initial_rotation = sprite.rotation

	# Collision setup: Layer 2, Mask 3 (Terrain layer 1 + Player layer 2)
	collision_layer = 2
	collision_mask = 3

	_update_type_and_visuals()

	# In gameplay, hide stone until player triggers the trigger area
	if not is_in_editor():
		visible = false
		is_falling = false
		if col_shape:
			col_shape.disabled = true
		set_physics_process(false)
	else:
		visible = true
		if col_shape:
			col_shape.disabled = false
		set_physics_process(false)


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
			var s_scale: Vector2 = sprite.scale
			var r: float = minf(t_size.x * absf(s_scale.x), t_size.y * absf(s_scale.y)) * 0.5
			if r > 5.0:
				target_radius = r
		elif is_lethal:
			target_radius = 35.0

		(col_shape.shape as CircleShape2D).radius = target_radius

	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_falling:
		return

	# Apply falling velocity and gravity until stone lands on floor
	if not has_landed and not is_on_floor():
		velocity.y = minf(1600.0, velocity.y + gravity * delta)
		if absf(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	else:
		velocity.y = 0.0
		if absf(velocity.x) > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		rotation_speed = move_toward(rotation_speed, 0.0, 10.0 * delta)

	if sprite:
		sprite.rotation += rotation_speed * delta

	# Cooldown for player re-hit after rebound
	if _hit_cooldown > 0.0:
		_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
		if _hit_cooldown <= 0.0 and velocity.y > 60.0:
			has_hit_player = false

	if is_inside_tree():
		move_and_slide()

		# Process collisions with Terrain and Player
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if not collider:
				continue

			var is_player = (collider is CharacterBody2D and collider.name.begins_with("Player")) \
				or collider.is_in_group("player") \
				or collider.has_method("apply_knockback") \
				or (collider.has_method("die") and not (collider is FallingStoneController))

			if is_player:
				if not has_hit_player:
					_handle_player_collision(collider, col)
					return
			else:
				var col_norm := col.get_normal()
				if is_on_floor() or col_norm.y < -0.6:
					# Landed on ground / floor
					if velocity.y > 160.0:
						velocity.y = -velocity.y * 0.25
						velocity.x *= 0.6
					else:
						has_landed = true
						velocity.y = 0.0
						velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
						rotation_speed = move_toward(rotation_speed, 0.0, 10.0 * delta)
					break
				elif absf(col_norm.x) > 0.6 and col_norm.y > -0.6:
					# Wall collision: bounce off wall in opposite direction and keep falling
					velocity.x = -velocity.x * 0.6
					rotation_speed = -rotation_speed * 0.7
					global_position += col_norm * 2.0
				elif col_norm.y > 0.6:
					# Ceiling collision: bounce down
					velocity.y = absf(velocity.y) * 0.5

	# Check if stone has landed on ground or stopped moving
	if (has_landed or is_on_floor()) and velocity.length_squared() < 250.0:
		_rest_timer += delta
		if _rest_timer >= 2.0:
			_deactivate_stone()
			return
	else:
		_rest_timer = 0.0

	# Stop falling when reaching maximum fall distance
	if start_pos != Vector2.ZERO and global_position.y > start_pos.y + fall_distance:
		_deactivate_stone()


func _handle_player_collision(player_node: Node2D, collision: KinematicCollision2D = null) -> void:
	if has_hit_player:
		return

	if is_lethal:
		# LETHAL (Spike Stone): Kills player on contact, then destroys/hides spike stone
		has_hit_player = true
		is_falling = false
		velocity = Vector2.ZERO

		if player_node.has_method("die") and not player_node.get("is_invulnerable"):
			player_node.die()
		elif player_node.has_method("game_over"):
			player_node.game_over()

		# Destroy/hide spike stone immediately upon player kill
		_deactivate_stone()
	else:
		# NON-LETHAL (Normal Falling Stone):
		# Real-life elastic impulse collision: normal force pushes player, reaction force pushes stone in exact opposite direction
		has_hit_player = true
		_hit_cooldown = 0.55

		var p_pos := player_node.global_position
		var contact_normal := (p_pos - global_position).normalized()
		if contact_normal == Vector2.ZERO or absf(contact_normal.x) < 0.12:
			var side = 1.0 if (p_pos.x >= global_position.x) else -1.0
			contact_normal = Vector2(side * 0.75, 0.65).normalized()

		# Player is propelled along collision contact normal (away from stone)
		var player_push_dir := contact_normal
		var p_impulse: Vector2 = player_push_dir * knockback_force

		if player_node.has_method("apply_knockback"):
			player_node.apply_knockback(p_impulse)
		elif "velocity" in player_node:
			player_node.velocity = p_impulse

		if "_input_lock" in player_node:
			player_node.set("_input_lock", 0.35)

		player_node.global_position += player_push_dir * 14.0

		# Newton's 3rd Law: Reaction force acts on stone in the EXACT OPPOSITE direction (-player_push_dir)
		# Bounces stone in opposite direction with upward and outward rebound, then falls back down under gravity
		var stone_rebound_dir := -player_push_dir
		var impact_speed: float = maxf(velocity.length(), fall_speed)
		var rebound_speed: float = clampf(impact_speed * 0.8, 500.0, 850.0)
		velocity = stone_rebound_dir * rebound_speed
		rotation_speed = -signf(player_push_dir.x) * randf_range(10.0, 16.0)
		has_landed = false
		_rest_timer = 0.0


func _deactivate_stone() -> void:
	is_falling = false
	visible = false
	velocity = Vector2.ZERO
	if col_shape:
		col_shape.set_deferred("disabled", true)
	set_physics_process(false)


## Called by TriggerArea when player touches the trigger zone
func trigger() -> void:
	if is_falling or has_fallen:
		return

	is_falling = true
	has_fallen = true
	has_hit_player = false
	has_landed = false
	_rest_timer = 0.0
	_hit_cooldown = 0.0
	visible = true
	if col_shape:
		col_shape.set_deferred("disabled", false)
	set_physics_process(true)
	velocity = Vector2(0.0, fall_speed)


## Reset stone state when player dies/respawns or level restarts
func reset() -> void:
	is_falling = false
	has_fallen = false
	has_hit_player = false
	has_landed = false
	_rest_timer = 0.0
	_hit_cooldown = 0.0
	velocity = Vector2.ZERO
	if start_pos != Vector2.ZERO:
		global_position = start_pos
	if sprite:
		sprite.rotation = initial_rotation

	# In gameplay, hide until triggered again
	if not is_in_editor():
		visible = false
		if col_shape:
			col_shape.disabled = true
		set_physics_process(false)
	else:
		visible = true
		if col_shape:
			col_shape.disabled = false
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
	draw_line(Vector2.ZERO, Vector2(0, line_len), col, 2.0)
	draw_circle(Vector2(0, line_len), 4.0, col)

	var font = ThemeDB.fallback_font
	if font:
		var type_str = "Spike Stone" if is_lethal else "Falling Stone"
		var label_str = "%s [%s]" % [type_str, trigger_tag]
		draw_string(font, Vector2(12, -4), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))
