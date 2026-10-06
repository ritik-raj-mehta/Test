@tool
extends StaticBody2D
class_name WallsController

enum WallType {
	TRIANGLE = 0,
	COMPANY_LOGO = 1
}

const TEXTURES: Dictionary = {
	WallType.TRIANGLE: "res://game/assets/sprites/obstacles/Trianglewall4.png",
	WallType.COMPANY_LOGO: "res://game/assets/sprites/obstacles/CompanyLogoWall3.png"
}

const SHAPES: Dictionary = {
	WallType.TRIANGLE: "res://game/assets/resources/RightAngledTriangle.tres",
	WallType.COMPANY_LOGO: "res://game/assets/resources/CompanyLogo.tres"
}

const SPRITE_SCALES: Dictionary = {
	WallType.TRIANGLE: Vector2(0.72, 0.637),
	WallType.COMPANY_LOGO: Vector2(1.0, 1.0)
}

@export var is_lethal: bool = false
@export_enum("Right Angled Triangle", "Company Logo") var wall_type: int = WallType.TRIANGLE:
	set(v):
		wall_type = clampi(v, 0, 1)
		_update_wall()

@export var flip_h: bool = false:
	set(v):
		flip_h = v
		_update_wall()

@export var flip_v: bool = false:
	set(v):
		flip_v = v
		_update_wall()

@export var scale_x: float = 1.0:
	set(v):
		scale_x = maxf(0.01, v)
		_update_wall()

@export var scale_y: float = 1.0:
	set(v):
		scale_y = maxf(0.01, v)
		_update_wall()

@onready var sprite_triangle: Sprite2D = get_node_or_null("Sprite2DTraiangle")
@onready var sprite_logo: Sprite2D = get_node_or_null("Sprite2DLogo")
@onready var single_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	set_meta("is_lethal", false)
	_resolve_nodes()
	_update_wall()


func _resolve_nodes() -> void:
	set_meta("is_lethal", false)
	if sprite_triangle == null:
		sprite_triangle = get_node_or_null("Sprite2DTraiangle")
	if sprite_logo == null:
		sprite_logo = get_node_or_null("Sprite2DLogo")
	if single_sprite == null:
		single_sprite = get_node_or_null("Sprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")


func update_components() -> void:
	_update_wall()


func _update_wall() -> void:
	_resolve_nodes()

	var tex_path: String = TEXTURES.get(wall_type, TEXTURES[WallType.TRIANGLE])
	var shape_path: String = SHAPES.get(wall_type, SHAPES[WallType.TRIANGLE])
	var base_scale: Vector2 = SPRITE_SCALES.get(wall_type, Vector2.ONE)

	var sign_x: float = -1.0 if flip_h else 1.0
	var sign_y: float = -1.0 if flip_v else 1.0

	# 1. Handle dual sprite setup (Sprite2DTraiangle & Sprite2DLogo)
	if sprite_triangle and sprite_logo:
		if wall_type == WallType.TRIANGLE:
			sprite_triangle.visible = true
			sprite_logo.visible = false
			sprite_triangle.scale = Vector2(SPRITE_SCALES[WallType.TRIANGLE].x * sign_x, SPRITE_SCALES[WallType.TRIANGLE].y * sign_y)
		else:
			sprite_triangle.visible = false
			sprite_logo.visible = true
			sprite_logo.scale = Vector2(SPRITE_SCALES[WallType.COMPANY_LOGO].x * sign_x, SPRITE_SCALES[WallType.COMPANY_LOGO].y * sign_y)
	elif sprite_triangle:
		sprite_triangle.visible = (wall_type == WallType.TRIANGLE)
		sprite_triangle.scale = Vector2(SPRITE_SCALES[WallType.TRIANGLE].x * sign_x, SPRITE_SCALES[WallType.TRIANGLE].y * sign_y)
	elif sprite_logo:
		sprite_logo.visible = (wall_type == WallType.COMPANY_LOGO)
		sprite_logo.scale = Vector2(SPRITE_SCALES[WallType.COMPANY_LOGO].x * sign_x, SPRITE_SCALES[WallType.COMPANY_LOGO].y * sign_y)

	# 2. Handle single Sprite2D setup
	if single_sprite:
		if ResourceLoader.exists(tex_path):
			single_sprite.texture = load(tex_path)
		single_sprite.scale = Vector2(base_scale.x * sign_x, base_scale.y * sign_y)

	# 3. Update Collision Shape
	if collision_shape:
		if ResourceLoader.exists(shape_path):
			collision_shape.shape = load(shape_path)
		collision_shape.scale = Vector2(sign_x, sign_y)
