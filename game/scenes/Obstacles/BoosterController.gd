@tool
extends Area2D
class_name BoosterController

enum ForceTier {
	TIER_1_LOW = 1,
	TIER_2_MEDIUM = 2,
	TIER_3_HIGH = 3,
	TIER_4_SUPER = 4,
	TIER_5_MEGA = 5,
	TIER_6_ULTRA = 6,
	TIER_7_HYPER = 7,
	TIER_8_EXTREME = 8,
	TIER_9_COLOSSAL = 9,
	TIER_10_HUGE = 10
}

const FORCE_TIERS: Dictionary = {
	ForceTier.TIER_1_LOW: 650.0,
	ForceTier.TIER_2_MEDIUM: 950.0,
	ForceTier.TIER_3_HIGH: 1300.0,
	ForceTier.TIER_4_SUPER: 1700.0,
	ForceTier.TIER_5_MEGA: 2200.0,
	ForceTier.TIER_6_ULTRA: 2800.0,
	ForceTier.TIER_7_HYPER: 3500.0,
	ForceTier.TIER_8_EXTREME: 4300.0,
	ForceTier.TIER_9_COLOSSAL: 5200.0,
	ForceTier.TIER_10_HUGE: 6200.0
}

@export_enum("Tier 1 - Low (650)", "Tier 2 - Medium (950)", "Tier 3 - High (1300)", "Tier 4 - Super (1700)", "Tier 5 - Mega (2200)", "Tier 6 - Ultra (2800)", "Tier 7 - Hyper (3500)", "Tier 8 - Extreme (4300)", "Tier 9 - Colossal (5200)", "Tier 10 - Huge (6200)") var force_tier: int = 2:
	set(v):
		force_tier = clampi(v, 1, 10)
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
var _is_boosting: bool = false


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	add_to_group("boosters")
	add_to_group("obstacle")

	collision_layer = 2
	collision_mask = 3  # Detect player on layer 1 & 2

	# Performance optimization: disable unnecessary frame callbacks
	set_process(false)
	set_physics_process(false)

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
	# Local UP vector rotated by the booster's global rotation (exact perpendicular launch normal)
	return Vector2.UP.rotated(global_rotation).normalized()


func _on_body_entered(body: Node2D) -> void:
	if _is_boosting:
		return

	var is_player = body is Player \
		or body.is_in_group("player") \
		or body.name.begins_with("Player") \
		or (body is CharacterBody2D and body.has_method("die"))

	if not is_player:
		return

	_is_boosting = true
	var tree = get_tree()
	if tree:
		tree.create_timer(0.2).timeout.connect(func(): _is_boosting = false)
	else:
		_is_boosting = false

	var push_dir: Vector2 = get_push_direction()
	var force: float = get_boost_force()
	var boost_rot: float = global_rotation

	# 1. Snap the player directly into the middle of the booster:
	# Orient player perpendicular to the booster pad surface
	body.rotation = boost_rot
	if "visual" in body and body.visual:
		body.visual.rotation = 0.0

	# Align player laterally onto the booster's exact middle centerline
	var tangent: Vector2 = Vector2.RIGHT.rotated(boost_rot)
	var center_point: Vector2 = global_position
	if has_node("CollisionShape2D"):
		var col = get_node("CollisionShape2D") as CollisionShape2D
		center_point = col.global_position

	var to_player: Vector2 = body.global_position - center_point
	var lateral_offset: float = to_player.dot(tangent)
	body.global_position -= tangent * lateral_offset

	# Position slightly along launch direction to ensure clean takeoff
	body.global_position += push_dir * 12.0

	# 2. Throw the player perpendicular up:
	if body.has_method("apply_directional_boost"):
		body.apply_directional_boost(push_dir, force, invulnerability_duration, boost_rot)
	elif body.has_method("apply_booster") and data:
		body.apply_booster(data)
	else:
		if "velocity" in body:
			body.velocity = push_dir * force
		if "is_invulnerable" in body:
			body.is_invulnerable = true
		if "_input_lock" in body:
			body.set("_input_lock", invulnerability_duration)


func reset() -> void:
	triggered = false
	_is_boosting = false
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
