@tool
extends Area2D
class_name HorizontalZoneStart

@export var area_width: float = 300.0:
	set(v):
		area_width = max(10.0, v)
		update_shape_size()
		queue_redraw()

@export var area_height: float = 300.0:
	set(v):
		area_height = max(10.0, v)
		update_shape_size()
		queue_redraw()

@export var target_drag_left_margin: float = 0.2:
	set(v):
		target_drag_left_margin = clamp(v, 0.0, 1.0)

@export var target_drag_right_margin: float = 0.2:
	set(v):
		target_drag_right_margin = clamp(v, 0.0, 1.0)

@export var target_drag_top_margin: float = 0.5:
	set(v):
		target_drag_top_margin = clamp(v, 0.0, 1.0)

@export var target_drag_bottom_margin: float = 0.5:
	set(v):
		target_drag_bottom_margin = clamp(v, 0.0, 1.0)

@export var horizontal_drag_enabled: bool = true
@export var vertical_drag_enabled: bool = true
@export var transition_speed: float = 3.0

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	add_to_group("horizontal_zone_start")
	collision_mask = 3
	update_shape_size()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

func update_shape_size() -> void:
	var col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		if not col.shape or not col.shape is RectangleShape2D:
			col.shape = RectangleShape2D.new()
		elif col.shape.resource_local_to_scene == false:
			col.shape = col.shape.duplicate()
		(col.shape as RectangleShape2D).size = Vector2(area_width, area_height)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		update_shape_size()
		queue_redraw()
		return

	CameraDragState.update_camera_transition(delta)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.name.begins_with("Player") or body.is_in_group("player") or body.has_method("game_over"):
		CameraDragState.apply_start_zone(
			body,
			target_drag_left_margin,
			target_drag_right_margin,
			target_drag_top_margin,
			target_drag_bottom_margin,
			horizontal_drag_enabled,
			vertical_drag_enabled,
			transition_speed
		)

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

	var rect = Rect2(-Vector2(area_width, area_height) / 2.0, Vector2(area_width, area_height))
	draw_rect(rect, Color(0.1, 0.8, 0.4, 0.35), true)
	draw_rect(rect, Color(0.1, 0.9, 0.4, 0.9), false, 2.5)

	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(-area_width / 2.0 + 10, 5), "HORIZONTAL DRAG START", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 1))
