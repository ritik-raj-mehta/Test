@tool
extends ObstacleController
class_name RotatingGearController

@export var rotation_speed: float = 2.0
@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	super._ready()
	_apply_theme()

func update_components() -> void:
	_apply_theme()

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotation += rotation_speed * delta

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
	var tex = WorldThemeRegistry.get_gear_texture(theme_id)
	if tex:
		sprite.texture = tex
