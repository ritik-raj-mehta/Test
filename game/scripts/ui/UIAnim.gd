class_name UIAnim
extends RefCounted

## Screen edge a control slides to / from.
enum Edge { LEFT, RIGHT, TOP, BOTTOM }

const _REST_META: StringName = &"ui_anim_rest_position"
const _FOLD_SCALE: Vector2 = Vector2(0.4, 0.4)


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


static func capture_rest(node: Control) -> void:
	_rest_position(node)

static func reset_rest(node: Control) -> void:
	if node and node.has_meta(_REST_META):
		node.remove_meta(_REST_META)

## Park a control off-screen instantly (no animation). Pair with slide_in().
static func hide_offscreen(node: Control, edge: Edge) -> void:
	node.position = _offscreen_position(node, edge, _rest_position(node))

## Instantly fold a control under `anchor`, invisible. Pair with drop_in().
static func fold(node: Control, anchor: Control) -> void:
	_rest_position(node)
	node.pivot_offset = node.size * 0.5
	node.position = _folded_position(node, anchor)
	node.modulate.a = 0.0
	node.scale = _FOLD_SCALE
	node.hide()

## Drop-down reveal: starts folded under `anchor` (e.g. the pause button), drops to its rest spot.
static func drop_in(node: Control, anchor: Control, delay: float = 0.0, duration: float = 0.35) -> Tween:
	var rest := _rest_position(node)
	node.pivot_offset = node.size * 0.5
	node.position = _folded_position(node, anchor)
	node.modulate.a = 0.0
	node.scale = _FOLD_SCALE
	node.show()
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", rest, duration).set_delay(delay)
	t.tween_property(node, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	t.tween_property(node, "scale", Vector2.ONE, duration).set_delay(delay)
	return t

## Reverse of drop_in: folds back under `anchor` and hides itself.
static func drop_out(node: Control, anchor: Control, delay: float = 0.0, duration: float = 0.22) -> Tween:
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(node, "position", _folded_position(node, anchor), duration).set_delay(delay)
	t.tween_property(node, "modulate:a", 0.0, duration).set_delay(delay)
	t.tween_property(node, "scale", _FOLD_SCALE, duration).set_delay(delay)
	t.finished.connect(node.hide)
	return t

static func _folded_position(node: Control, anchor: Control) -> Vector2:
	var center := anchor.get_global_rect().get_center()
	var parent := node.get_parent() as CanvasItem
	if parent:
		center = parent.get_global_transform().affine_inverse() * center
	return center - node.size * 0.5
