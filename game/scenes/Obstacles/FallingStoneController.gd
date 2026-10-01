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
var has_impacted: bool = false
var start_pos: Vector2 = Vector2.ZERO
var initial_rotation: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	add_to_group("falling_stone")
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

	if is_inside_tree():
		if is_lethal:
			if not is_in_group("obstacle"):
				add_to_group("obstacle")
		else:
			if is_in_group("obstacle"):
				remove_from_group("obstacle")

	set_meta("is_lethal", is_lethal)

	if col_shape:
		if not col_shape.shape or not col_shape.shape is CircleShape2D:
			col_shape.shape = CircleShape2D.new()
		elif not col_shape.shape.resource_local_to_scene:
			col_shape.shape = col_shape.shape.duplicate()
		(col_shape.shape as CircleShape2D).radius = 50.0 if is_lethal else 45.0

	_apply_theme()

	if Engine.is_editor_hint():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Stone remains suspended until triggered by TriggerArea
	if not is_falling:
		return

	# Apply falling velocity and gravity
	velocity.y = max(fall_speed, velocity.y + gravity * delta)
	velocity.x = 0.0

	if sprite:
		sprite.rotation += rotation_speed * delta

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
			_handle_player_collision(collider)
			break
		elif is_on_floor() or collider is StaticBody2D or collider is TileMapLayer:
			# Hit ground/terrain -> stop falling
			is_falling = false
			velocity = Vector2.ZERO
			has_impacted = true
			break

	# Stop falling when reaching maximum fall distance
	if start_pos != Vector2.ZERO and global_position.y > start_pos.y + fall_distance:
		is_falling = false
		visible = false
		velocity = Vector2.ZERO


func _handle_player_collision(player_node: Node2D) -> void:
	if has_impacted:
		return

	if is_lethal:
		# LETHAL (FallingStoneSpike): Triggers existing player death system
		has_impacted = true
		is_falling = false
		velocity = Vector2.ZERO

		if player_node.has_method("die") and not player_node.get("is_invulnerable"):
			player_node.die()
		elif player_node.has_method("game_over"):
			player_node.game_over()
	else:
		# NON-LETHAL (FallingStone): Player survives and receives physical knockback
		has_impacted = true
		is_falling = false
		velocity = Vector2.ZERO

		var p_pos := player_node.global_position
		var push_dir := (p_pos - global_position).normalized()

		# If direct downward hit or centered, push diagonally away from stone center
		if push_dir == Vector2.ZERO or abs(push_dir.x) < 0.15:
			var side = 1.0 if p_pos.x >= global_position.x else -1.0
			push_dir = Vector2(side * 0.85, 0.52).normalized()

		var impulse := push_dir * knockback_force

		# Apply knockback to player using player physics
		if player_node.has_method("apply_knockback"):
			player_node.apply_knockback(impulse)
		elif "velocity" in player_node:
			player_node.velocity = impulse

		# Separate player slightly to prevent getting stuck
		player_node.global_position += push_dir * 16.0


## Called by TriggerArea when player touches the trigger zone
func trigger() -> void:
	if is_falling or has_fallen:
		return

	is_falling = true
	has_fallen = true
	has_impacted = false
	visible = true
	velocity = Vector2(0, fall_speed)


## Reset stone state when player dies/respawns or level restarts
func reset() -> void:
	is_falling = false
	has_fallen = false
	has_impacted = false
	visible = true
	velocity = Vector2.ZERO
	if start_pos != Vector2.ZERO:
		global_position = start_pos
	if sprite:
		sprite.rotation = initial_rotation


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

