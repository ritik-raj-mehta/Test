@tool
extends Node2D
class_name MovingGearWithRodController

@export var rotation_speed: float = 2.0
@export var move_speed: float = 150.0:
	set(v):
		move_speed = v
		_update_caches()

@export var move_distance: float = 300.0:
	set(v):
		move_distance = max(1.0, v)
		_update_caches()

@export var move_angle: float = 0.0: # degrees: 0 = +X (Right), 180 = -X (Left), 90 = +Y (Down), -90/270 = -Y (Up)
	set(v):
		move_angle = v
		_update_caches()

@export_enum("+X (Right)", "-X (Left)", "+Y (Down)", "-Y (Up)", "Custom") var move_direction: String = "+X":
	set(v):
		move_direction = v
		_sync_direction_enum()

@export var loop_reset: bool = true: # True = wrap to origin upon reaching end; False = ping-pong back and forth
	set(v):
		loop_reset = v
		_update_caches()

@export var rod_breadth: float = 8.0:
	set(v):
		rod_breadth = max(1.0, v)
		_update_rod_transform()

@export var gear_count: int = 1: # Number of moving gears on the rod
	set(v):
		gear_count = clampi(v, 1, 20)
		_rebuild_gears()
		_update_caches()

@export_range(0.0, 5000.0, 1.0, "or_greater") var gear_spacing: float = 100.0: # Distance between each gear along the track (0 = auto-spaced)
	set(v):
		gear_spacing = max(0.0, v)
		_update_caches()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

@onready var rod_sprite: Sprite2D = $RodSprite if has_node("RodSprite") else null
@onready var gear_body: StaticBody2D = $GearBody if has_node("GearBody") else null
@onready var gear_sprite: Sprite2D = $GearBody/Sprite2D if has_node("GearBody/Sprite2D") else null

# Precomputed O(1) physics caches and gear body pool
var _move_dir_vec: Vector2 = Vector2.RIGHT
var _progress: float = 0.0
var _elapsed_time: float = 0.0
var _has_movement: bool = false
var _gear_bodies: Array[StaticBody2D] = []
var _gear_sprites: Array[Sprite2D] = []

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	_rebuild_gears()
	_apply_theme()
	_update_caches()

func update_components() -> void:
	_rebuild_gears()
	_apply_theme()
	_update_caches()

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

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

	# Remove any previously spawned clone children (including internal nodes)
	for child in get_children(true):
		if child != gear_body and (child.name.begins_with("GearBody_Clone_") or child.is_in_group("gear_clone")):
			child.queue_free()
			remove_child(child)

	var target_count = max(1, gear_count)
	for i in range(1, target_count):
		if gear_body:
			var clone = gear_body.duplicate() as StaticBody2D
			clone.name = "GearBody_Clone_%d" % i
			clone.add_to_group("gear_clone")
			# INTERNAL_MODE_BACK ensures clones are not saved into the .tscn file and don't dirty the editor scene
			add_child(clone, false, Node.INTERNAL_MODE_BACK)
			_gear_bodies.append(clone)
			var spr = clone.get_node_or_null("Sprite2D") as Sprite2D
			if spr:
				_gear_sprites.append(spr)

func _apply_theme() -> void:
	if rod_sprite == null and has_node("RodSprite"):
		rod_sprite = get_node("RodSprite") as Sprite2D

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	if rod_sprite:
		var r_tex = WorldThemeRegistry.get_gear_rod_texture(theme_id)
		if r_tex:
			rod_sprite.texture = r_tex

	var g_tex = WorldThemeRegistry.get_gear_texture(theme_id)
	if g_tex:
		for spr in _gear_sprites:
			if spr:
				spr.texture = g_tex

	_update_rod_transform()

func _sync_direction_enum() -> void:
	match move_direction:
		"+X", "+X (Right)":
			move_angle = 0.0
		"-X", "-X (Left)":
			move_angle = 180.0
		"+Y", "+Y (Down)":
			move_angle = 90.0
		"-Y", "-Y (Up)":
			move_angle = -90.0
	_update_caches()

func _update_caches() -> void:
	var rad = deg_to_rad(move_angle)
	_move_dir_vec = Vector2(cos(rad), sin(rad))
	_has_movement = (move_distance > 0.0) and (move_speed > 0.0)
	_update_rod_transform()
	_update_gears_positions(_progress)

func _update_rod_transform() -> void:
	if rod_sprite == null and has_node("RodSprite"):
		rod_sprite = get_node("RodSprite") as Sprite2D
	if not rod_sprite:
		return

	var rad = deg_to_rad(move_angle)
	# Rod starts at (0, 0) and extends to _move_dir_vec * move_distance, midpoint is half distance
	rod_sprite.position = _move_dir_vec * (move_distance * 0.5)
	# Rod sprite is vertical in source texture, rotate by angle + 90 deg
	rod_sprite.rotation = rad + (PI * 0.5)

	if rod_sprite.texture:
		var tex_h = float(rod_sprite.texture.get_height())
		var tex_w = float(rod_sprite.texture.get_width())
		if tex_h > 0.0:
			rod_sprite.scale.y = move_distance / tex_h
		if tex_w > 0.0:
			rod_sprite.scale.x = rod_breadth / tex_w

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Rotate all gear sprites
	if rotation_speed != 0.0:
		for spr in _gear_sprites:
			if spr:
				spr.rotation += rotation_speed * delta

	# Move all gears along the fixed rod
	if _has_movement:
		_elapsed_time += delta
		if loop_reset:
			_progress += (move_speed / move_distance) * delta
			if _progress >= 1.0:
				_progress = fmod(_progress, 1.0)
		else:
			_progress = _elapsed_time * (move_speed / 50.0)

		_update_gears_positions(_progress)

func _update_gears_positions(prog: float) -> void:
	var count = _gear_bodies.size()
	if count == 0:
		return

	var effective_spacing = gear_spacing
	if is_zero_approx(effective_spacing):
		effective_spacing = move_distance / float(count)

	for i in range(count):
		var body = _gear_bodies[i]
		if not body:
			continue

		var current_dist: float = 0.0
		if loop_reset:
			# Each gear has offset along the track, wrapping seamlessly from 0 to move_distance
			var gear_prog = fposmod(prog + (float(i) * effective_spacing / move_distance), 1.0)
			current_dist = gear_prog * move_distance
		else:
			# Ping-pong oscillation with phase offset
			var phase = prog + (float(i) * effective_spacing / max(1.0, move_distance)) * PI * 2.0
			current_dist = (1.0 - cos(phase)) * 0.5 * move_distance

		body.position = _move_dir_vec * current_dist

func reset() -> void:
	_progress = 0.0
	_elapsed_time = 0.0
	_update_gears_positions(0.0)
