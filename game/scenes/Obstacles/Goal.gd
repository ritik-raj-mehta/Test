@tool
extends Area2D
class_name Goal

var _bus: Node

func setup(bus: Node) -> void:
	_bus = bus

@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

var triggered: bool = false
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	collision_mask = 3   # player on layer 1 or 2
	monitoring = true
	_apply_theme()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return

	if body is CharacterBody2D or body.name.begins_with("Player") or body.is_in_group("player"):
		triggered = true
		if _bus:
			_bus.goal_reached.emit(body, self)


func get_goal_position() -> Vector2:
	if has_node("AttractionPoint"):
		return (get_node("AttractionPoint") as Node2D).global_position
	if sprite:
		return sprite.global_position
	return global_position


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

	var tex = WorldThemeRegistry.get_fruit_texture(theme_id)
	if tex:
		sprite.texture = tex
		# Normalize fruit size smoothly across different resolutions
		var tex_sz = tex.get_size()
		if tex_sz.x > 0 and tex_sz.y > 0:
			var max_dim = max(tex_sz.x, tex_sz.y)
			var scale_factor = 90.0 / max_dim
			sprite.scale = Vector2(scale_factor, scale_factor)


func reset() -> void:
	triggered = false
