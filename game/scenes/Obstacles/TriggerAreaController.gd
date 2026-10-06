@tool
extends Area2D
class_name TriggerAreaController

@export var trigger_tag: String = "trap_1":
	set(v):
		trigger_tag = v
		queue_redraw()

@export var area_width: float = 200.0:
	set(v):
		area_width = max(10.0, v)
		update_shape_size()
		queue_redraw()

@export var area_height: float = 150.0:
	set(v):
		area_height = max(10.0, v)
		update_shape_size()
		queue_redraw()

var triggered: bool = false
var _retrigger_cooldown: float = 0.0

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	add_to_group("trigger_area")
	collision_mask = 3
	update_shape_size()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)

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
	elif _retrigger_cooldown > 0.0:
		_retrigger_cooldown = maxf(_retrigger_cooldown - delta, 0.0)

func _is_player(body: Node2D) -> bool:
	return body is Player \
		or body.is_in_group("player") \
		or body.name.begins_with("Player") \
		or (body is CharacterBody2D and not (body is FallingStoneController) and body.has_method("die"))

func _on_body_entered(body: Node2D) -> void:
	if triggered or _retrigger_cooldown > 0.0:
		return

	if _is_player(body):
		triggered = true
		_retrigger_cooldown = 0.25
		activate_triggers()

func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		triggered = false

func activate_triggers() -> void:
	# Trigger all nodes in "triggerable" group with matching trigger_tag
	var nodes = get_tree().get_nodes_in_group("triggerable")
	for node in nodes:
		if node == self:
			continue
		var tag_match := true
		if "trigger_tag" in node and trigger_tag != "":
			tag_match = (node.trigger_tag == trigger_tag or node.trigger_tag == "")
		if tag_match and node.has_method("trigger"):
			node.trigger()

func is_in_editor() -> bool:
	if Engine.is_editor_hint():
		return true
	var n: Node = self
	while n:
		if n.name == "LevelEditor" or n.name == "LevelCanvas" or n.has_method("new_level") or n.is_in_group("level_editor"):
			return true
		n = n.get_parent()
	return false

func reset() -> void:
	triggered = false

func _draw() -> void:
	if not is_in_editor():
		return

	var rect = Rect2(-Vector2(area_width, area_height) / 2.0, Vector2(area_width, area_height))
	draw_rect(rect, Color(1.0, 0.8, 0.1, 0.35), true)
	draw_rect(rect, Color(1.0, 0.8, 0.1, 0.9), false, 2.5)
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(-area_width / 2.0 + 10, 5), "TRIGGER: " + trigger_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 1))
