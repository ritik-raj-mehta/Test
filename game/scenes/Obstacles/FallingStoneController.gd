@tool
extends CharacterBody2D
class_name FallingStoneController

@export var is_lethal: bool = false
@export var trigger_tag: String = "trap_1"
@export var fall_speed: float = 600.0
@export var gravity: float = 1200.0
@export var rotation_speed: float = 4.0
@export var fall_distance: float = 3000.0
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
	if is_lethal:
		add_to_group("obstacle")

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

	_apply_theme()


func update_components() -> void:
	start_pos = global_position
	if sprite:
		initial_rotation = sprite.rotation
	_apply_theme()


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
