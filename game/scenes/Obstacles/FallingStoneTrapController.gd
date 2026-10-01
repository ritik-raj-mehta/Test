@tool
extends Node2D
class_name FallingStoneTrapController

@export var trigger_distance_y: float = 300.0
@export var fall_speed: float = 600.0
@export var trigger_width: float = 200.0
@export var world_theme: String = "":
	set(v):
		world_theme = v
		_apply_theme()

@onready var stone: FallingStoneController = $FallingStone if has_node("FallingStone") else null
@onready var trigger_zone: TriggerAreaController = $TriggerArea if has_node("TriggerArea") else null

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	update_components()
	_apply_theme()

func update_components() -> void:
	if trigger_zone:
		trigger_zone.position = Vector2(0, trigger_distance_y)
		trigger_zone.area_width = trigger_width
		trigger_zone.area_height = 100.0
		trigger_zone.update_shape_size()
	if stone:
		stone.fall_speed = fall_speed

func apply_theme(theme_id: String) -> void:
	world_theme = theme_id
	_apply_theme()

func _apply_theme() -> void:
	if stone == null and has_node("FallingStone"):
		stone = get_node("FallingStone") as FallingStoneController
	if stone and stone.has_method("apply_theme"):
		var t_id = world_theme
		if t_id == "":
			t_id = WorldThemeRegistry.get_current_theme()
		stone.apply_theme(t_id)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		update_components()
		queue_redraw()

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
	if is_in_editor():
		draw_line(Vector2.ZERO, Vector2(0, trigger_distance_y), Color(1.0, 0.4, 0.4, 0.8), 2.0)
