class_name UIAnim
extends RefCounted

## Screen edge a control slides to / from.
enum Edge { LEFT, RIGHT, TOP, BOTTOM }

const _REST_META: StringName = &"ui_anim_rest_position"


static func pop_in(node: Control, duration: float = UIConfig.POPUP_IN_SECONDS) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.85, 0.85)
	await node.get_tree().process_frame
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, duration)
	t.tween_property(node, "scale", Vector2.ONE, duration)

static func pop_out(node: Control, duration: float = UIConfig.POPUP_OUT_SECONDS) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "modulate:a", 0.0, duration)
	t.tween_property(node, "scale", Vector2(0.9, 0.9), duration)
	await t.finished

static func pulse(node: Control, amount: float = 0.07, duration: float = 0.7) -> void:
	await node.get_tree().process_frame
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), duration)
	t.tween_property(node, "scale", Vector2.ONE, duration)

static func shake(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween()
	for deg in [-6.0, 6.0, -4.0, 4.0, 0.0]:
		t.tween_property(node, "rotation_degrees", deg, 0.05)

static func bounce(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.9, 0.9)
	node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(node, "scale", Vector2.ONE, 0.18)


static func slide_in(node: Control, edge: Edge, delay: float = 0.0, duration: float = 0.45) -> Tween:
	var rest := _rest_position(node)
	node.position = _offscreen_position(node, edge, rest)
	var t := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", rest, duration).set_delay(delay)
	return t

static func slide_out(node: Control, edge: Edge, delay: float = 0.0, duration: float = 0.3) -> Tween:
	var rest := _rest_position(node)
	var t := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(node, "position", _offscreen_position(node, edge, rest), duration).set_delay(delay)
	return t

static func _rest_position(node: Control) -> Vector2:
	if not node.has_meta(_REST_META):
		node.set_meta(_REST_META, node.position)
	return node.get_meta(_REST_META)

static func _offscreen_position(node: Control, edge: Edge, rest: Vector2, margin: float = 24.0) -> Vector2:
	var screen := node.get_viewport_rect().size
	var origin := node.get_global_rect().position - node.position + rest  # global top-left at rest
	match edge:
		Edge.LEFT:
			return rest + Vector2(-(origin.x + node.size.x + margin), 0.0)
		Edge.RIGHT:
			return rest + Vector2(screen.x - origin.x + margin, 0.0)
		Edge.TOP:
			return rest + Vector2(0.0, -(origin.y + node.size.y + margin))
		_:
			return rest + Vector2(0.0, screen.y - origin.y + margin)
