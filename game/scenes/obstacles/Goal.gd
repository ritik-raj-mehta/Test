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
		_set_cry(true)
		if _bus:
			_bus.goal_reached.emit(body, self)


func get_goal_position() -> Vector2:
	if has_node("AttractionPoint"):
		return (get_node("AttractionPoint") as Node2D).global_position
	if sprite:
		return sprite.global_position
	return global_position


func _apply_theme() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	if not sprite:
		return
	_set_fruit_tex(WorldThemeRegistry.get_fruit_texture(_theme_id()))


func _theme_id() -> String:
	return world_theme if world_theme != "" else WorldThemeRegistry.get_current_theme()


func _set_cry(on: bool) -> void:
	if not sprite:
		return
	var tex: Texture2D = null
	if on:
		tex = WorldThemeRegistry.get_fruit_cry_texture(_theme_id())
	if tex == null:
		tex = WorldThemeRegistry.get_fruit_texture(_theme_id())
	_set_fruit_tex(tex)


func _set_fruit_tex(tex: Texture2D) -> void:
	if not tex:
		return
	sprite.texture = tex
	var sz := tex.get_size()
	if sz.x > 0 and sz.y > 0:
		var f := 90.0 / maxf(sz.x, sz.y)
		sprite.scale = Vector2(f, f)


func reset() -> void:
	triggered = false
	_set_cry(false)

func on_eaten() -> void:
	_set_cry(true)
	if sprite:
		var base := sprite.scale
		var t := create_tween()
		t.tween_property(sprite, "scale", base * 1.15, 0.08)
		t.tween_property(sprite, "scale", base, 0.12)
