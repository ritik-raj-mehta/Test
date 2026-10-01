@tool
extends Area2D
class_name BoosterController

enum ForceTier {
	TIER_1_LOW = 1,
	TIER_2_MEDIUM = 2,
	TIER_3_HIGH = 3,
	TIER_4_SUPER = 4,
	TIER_5_MEGA = 5
}

const FORCE_TIERS: Dictionary = {
	ForceTier.TIER_1_LOW: 650.0,
	ForceTier.TIER_2_MEDIUM: 950.0,
	ForceTier.TIER_3_HIGH: 1300.0,
	ForceTier.TIER_4_SUPER: 1700.0,
	ForceTier.TIER_5_MEGA: 2200.0
}

@export_enum("Tier 1 - Low (650)", "Tier 2 - Medium (950)", "Tier 3 - High (1300)", "Tier 4 - Super (1700)", "Tier 5 - Mega (2200)") var force_tier: int = 2:
	set(v):
		force_tier = clampi(v, 1, 5)
		if Engine.is_editor_hint():
			queue_redraw()

@export var custom_force: float = 0.0:
	set(v):
		custom_force = max(0.0, v)
		if Engine.is_editor_hint():
			queue_redraw()

@export var invulnerability_duration: float = 0.6
@export var data: BoosterData

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

var triggered: bool = false


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	add_to_group("boosters")
	add_to_group("obstacle")

	collision_layer = 2
	collision_mask = 3  # Detect player on layer 1 & 2

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D

	if sprite and sprite.texture == null:
		var tex_path = "res://game/assets/sprites/obstacles/Booster.png"
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)


func get_boost_force() -> float:
	if custom_force > 0.0:
		return custom_force
	return FORCE_TIERS.get(force_tier, 950.0)


func get_push_direction() -> Vector2:
	# Local UP vector rotated by the booster's global rotation
	return Vector2.UP.rotated(global_rotation).normalized()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.name.begins_with("Player") or body.is_in_group("player"):
		var push_dir = get_push_direction()
		var force = get_boost_force()

		if body.has_method("apply_directional_boost"):
			body.apply_directional_boost(push_dir, force, invulnerability_duration)
		elif body.has_method("apply_booster"):
			if data:
				body.apply_booster(data)
			else:
				if "velocity" in body:
					body.velocity = push_dir * force
				if "is_invulnerable" in body:
					body.is_invulnerable = true


func reset() -> void:
	triggered = false
	visible = true
	monitoring = true


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

	# Draw launch direction arrow in editor preview
	var arrow_len = 45.0 + float(force_tier) * 8.0
	var tip = Vector2.UP * arrow_len
	draw_line(Vector2.ZERO, tip, Color(0.2, 1.0, 0.4, 0.9), 3.0)
	draw_line(tip, tip + Vector2(-8, 12), Color(0.2, 1.0, 0.4, 0.9), 3.0)
	draw_line(tip, tip + Vector2(8, 12), Color(0.2, 1.0, 0.4, 0.9), 3.0)

	var font = ThemeDB.fallback_font
	if font:
		var txt = "T%d (%.0f)" % [force_tier, get_boost_force()]
		draw_string(font, Vector2(-25, -arrow_len - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.9))
