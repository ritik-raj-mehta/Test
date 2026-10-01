@tool
extends ObstacleController
class_name GearRodeController

@export var length: float = 200.0:
	set(v):
		length = max(1.0, v)
		_update_rod_dimensions()

@export var breadth: float = 8.0:
	set(v):
		breadth = max(1.0, v)
		_update_rod_dimensions()

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

@onready var sprite_rod: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	super._ready()
	_apply_theme()
	_update_rod_dimensions()

func update_components() -> void:
	_apply_theme()
	_update_rod_dimensions()

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

func _apply_theme() -> void:
	if sprite_rod == null and has_node("Sprite2D"):
		sprite_rod = get_node("Sprite2D") as Sprite2D
	if not sprite_rod:
		return

	var theme_id = world_theme
	if theme_id == "":
		theme_id = WorldThemeRegistry.get_current_theme()

	var r_tex = WorldThemeRegistry.get_gear_rod_texture(theme_id)
	if r_tex:
		sprite_rod.texture = r_tex
		_update_rod_dimensions()

func _update_rod_dimensions() -> void:
	if sprite_rod == null and has_node("Sprite2D"):
		sprite_rod = get_node("Sprite2D") as Sprite2D

	if sprite_rod and sprite_rod.texture:
		var tex_h = float(sprite_rod.texture.get_height())
		var tex_w = float(sprite_rod.texture.get_width())
		if tex_h > 0.0:
			# The sprite is rotated by 90 degrees (1.5707964 rad), so sprite_rod.scale.y scales length along local X
			sprite_rod.scale.y = length / tex_h
		if tex_w > 0.0:
			# sprite_rod.scale.x scales breadth/thickness along local Y
			sprite_rod.scale.x = breadth / tex_w

	if collision_shape == null and has_node("CollisionShape2D"):
		collision_shape = get_node("CollisionShape2D") as CollisionShape2D

	if collision_shape:
		if not collision_shape.shape or not collision_shape.shape is RectangleShape2D:
			collision_shape.shape = RectangleShape2D.new()
		elif not collision_shape.shape.resource_local_to_scene:
			collision_shape.shape = collision_shape.shape.duplicate()
		(collision_shape.shape as RectangleShape2D).size = Vector2(length, breadth)
