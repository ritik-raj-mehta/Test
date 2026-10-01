@tool
extends Node2D
class_name HorizontalZoneTrigger

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

@export var end_offset_x: float = 800.0:
	set(v):
		end_offset_x = v
		update_shape_size()
		queue_redraw()

@export var end_offset_y: float = 0.0:
	set(v):
		end_offset_y = v
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

var _is_in_horizontal_mode: bool = false
var _target_player: Node2D = null

# Baseline camera drag settings cached when entering start zone
var _baseline_cached: bool = false
var _baseline_drag_left: float = 0.2
var _baseline_drag_right: float = 0.2
var _baseline_drag_top: float = 0.8
var _baseline_drag_bottom: float = 0.8
var _baseline_horiz_enabled: bool = true
var _baseline_vert_enabled: bool = true

@onready var start_area: Area2D = $StartArea
@onready var end_area: Area2D = $EndArea
@onready var start_shape: CollisionShape2D = $StartArea/CollisionShape2D
@onready var end_shape: CollisionShape2D = $EndArea/CollisionShape2D

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	add_to_group("horizontal_zone_trigger")
	update_shape_size()

	if not Engine.is_editor_hint():
		var sa = get_node_or_null("StartArea") as Area2D
		if sa and not sa.body_entered.is_connected(_on_start_body_entered):
			sa.body_entered.connect(_on_start_body_entered)

		var ea = get_node_or_null("EndArea") as Area2D
		if ea and not ea.body_entered.is_connected(_on_end_body_entered):
			ea.body_entered.connect(_on_end_body_entered)

func update_shape_size() -> void:
	var s_area = get_node_or_null("StartArea") as Area2D
	var s_shape = get_node_or_null("StartArea/CollisionShape2D") as CollisionShape2D
	var e_area = get_node_or_null("EndArea") as Area2D
	var e_shape = get_node_or_null("EndArea/CollisionShape2D") as CollisionShape2D

	if s_shape:
		if not s_shape.shape or not s_shape.shape is RectangleShape2D:
			s_shape.shape = RectangleShape2D.new()
		elif s_shape.shape.resource_local_to_scene == false:
			s_shape.shape = s_shape.shape.duplicate()
		(s_shape.shape as RectangleShape2D).size = Vector2(area_width, area_height)

	if e_area:
		e_area.position = Vector2(end_offset_x, end_offset_y)

	if e_shape:
		if not e_shape.shape or not e_shape.shape is RectangleShape2D:
			e_shape.shape = RectangleShape2D.new()
		elif e_shape.shape.resource_local_to_scene == false:
			e_shape.shape = e_shape.shape.duplicate()
		(e_shape.shape as RectangleShape2D).size = Vector2(area_width, area_height)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		update_shape_size()
		queue_redraw()
		return

	CameraDragState.update_camera_transition(delta)

func _on_start_body_entered(body: Node2D) -> void:
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

func _on_end_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.name.begins_with("Player") or body.is_in_group("player") or body.has_method("game_over"):
		CameraDragState.apply_end_zone(body, transition_speed)

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

	# Draw Start Area (Cyan / Green)
	var start_rect = Rect2(-Vector2(area_width, area_height) / 2.0, Vector2(area_width, area_height))
	draw_rect(start_rect, Color(0.1, 0.8, 0.4, 0.35), true)
	draw_rect(start_rect, Color(0.1, 0.9, 0.4, 0.9), false, 2.5)

	# Draw End Area (Orange / Red) at end_offset
	var end_pos = Vector2(end_offset_x, end_offset_y)
	var end_rect = Rect2(end_pos - Vector2(area_width, area_height) / 2.0, Vector2(area_width, area_height))
	draw_rect(end_rect, Color(1.0, 0.4, 0.2, 0.35), true)
	draw_rect(end_rect, Color(1.0, 0.4, 0.2, 0.9), false, 2.5)

	# Draw connection line between Start and End areas
	draw_line(Vector2.ZERO, end_pos, Color(1.0, 0.9, 0.2, 0.8), 2.5)

	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(-area_width / 2.0 + 10, 5), "START HORIZONTAL ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 1))
		draw_string(font, end_pos + Vector2(-area_width / 2.0 + 10, 5), "END HORIZONTAL ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 1))
