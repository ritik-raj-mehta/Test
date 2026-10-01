class_name SkinCarousel
extends Control

## Snap carousel of character PREFABS: selected item is big, neighbours are small.
## Works with arrow buttons (previous()/next()), mouse/touch drag, and tap on a neighbour.
##
## Assign your character prefabs in the Inspector (`Prefabs` array). Their ORDER must match
## SkinCatalog's order (prefab i = skin i).
##
## A prefab root can be a Control (kept at its own size, centred) or a Node2D (origin = centre).
## Optional methods on the prefab root:
##   set_locked(locked: bool)  - custom locked look. If absent, the carousel tints it black
##                               and shows a lock icon itself.
##   bounce()                  - custom "selected" animation. If absent, UIAnim.bounce is used.

signal selected(index: int)   ## snap target changed (fires immediately)
signal moving()               ## drag started or a snap animation started
signal settled(index: int)    ## carousel came to rest on `index`

# const LOCK_TEXTURE := preload("res://game/assets/sprites/single/ui/DailyMissionLockIcon.png")
# const LOCKED_TINT := Color("#000000c0")

@export var prefabs: Array[PackedScene] = []  ## one per skin, same order as SkinCatalog
@export var slot_size: Vector2 = Vector2(300, 400)  ## minimum item size; grows to fit the biggest prefab
@export var auto_spacing: bool = true    ## derive spacing from the real item size
@export var gap: float = 24.0            ## px gap between centre item and neighbours (auto_spacing)
@export var spacing: float = 250.0       ## px between item centres (used when auto_spacing is off)
@export var center_scale: float = 1.0
@export var side_scale: float = 0.55
@export var side_alpha: float = 0.85
@export var tap_threshold: float = 12.0  ## px; below this a release counts as a tap
@export var snap_time: float = 0.28
@export var flick_factor: float = 0.15   ## how far a fast flick projects the snap target

var _slots: Array[Control] = []    # scaled / positioned by the carousel
var _holders: Array[Control] = []  # inside slot: holds the prefab (tint + bounce target)
var _nodes: Array[Node] = []       # the prefab instances
var _locks: Array[TextureRect] = []
var _offset: float = 0.0   ## continuous position in "item index" units
var _index: int = 0        ## current snap target
var _tween: Tween
var _dragging: bool = false
var _drag_distance: float = 0.0
var _velocity: float = 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

## Instances every prefab from `prefabs` and lays them out.
func build(start_index: int = 0) -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	_holders.clear()
	_nodes.clear()
	_locks.clear()

	# 1) instance prefabs and measure them (they can all differ in size)
	var item := slot_size
	var sizes: Array[Vector2] = []
	for scene in prefabs:
		if scene == null:
			push_warning("SkinCarousel: empty slot in `prefabs` – assign a scene.")
			continue
		var node := scene.instantiate()
		var node_size := Vector2.ZERO
		if node is Control:
			add_child(node)
			node_size = node.get_combined_minimum_size().max(node.size)
			remove_child(node)
		sizes.append(node_size)
		_nodes.append(node)
		item = item.max(node_size)
	slot_size = item
	# if auto_spacing:
	# 	spacing = slot_size.x * (center_scale + side_scale) * 0.5 + gap

	# 2) wrap each prefab: slot -> holder -> prefab (+ lock icon on the slot)
	for i in _nodes.size():
		var node := _nodes[i]
		var slot := Control.new()
		slot.size = slot_size
		slot.pivot_offset = slot_size * 0.5
		var holder := Control.new()
		holder.size = slot_size
		holder.pivot_offset = slot_size * 0.5
		slot.add_child(holder)
		holder.add_child(node)
		if node is Control:
			node.set_anchors_preset(Control.PRESET_TOP_LEFT)
			node.size = sizes[i]
			node.position = (slot_size - sizes[i]) * 0.5
		elif node is Node2D:
			node.position = slot_size * 0.5
		var lock := TextureRect.new()
		# lock.texture = LOCK_TEXTURE
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.size = Vector2(100, 100)
		lock.position = Vector2((slot_size.x - 100.0) * 0.5, slot_size.y * 0.14)
		lock.visible = false
		slot.add_child(lock)
		add_child(slot)
		_ignore_mouse(slot)  # so the carousel itself receives every drag
		_slots.append(slot)
		_holders.append(holder)
		_locks.append(lock)

	_index = clampi(start_index, 0, maxi(_slots.size() - 1, 0))
	_offset = float(_index)
	_layout()

func node_at(i: int) -> Node:
	return _nodes[i]

func current_index() -> int:
	return _index

## Locked skins are shown as a dark silhouette + lock icon (unless the prefab has set_locked()).
func set_locked(i: int, locked: bool) -> void:
	var node := _nodes[i]
	if node.has_method("set_locked"):
		_holders[i].modulate = Color.WHITE
		_locks[i].visible = false
		node.set_locked(locked)
	else:
		# _holders[i].modulate = LOCKED_TINT if locked else Color.WHITE
		_locks[i].visible = locked

func bounce_at(i: int) -> void:
	var node := _nodes[i]
	if node.has_method("bounce"):
		node.bounce()
	else:
		UIAnim.bounce(_holders[i])

func next() -> void:
	go_to(_index + 1)

func previous() -> void:
	go_to(_index - 1)

func go_to(i: int) -> void:
	if _slots.is_empty():
		return
	i = clampi(i, 0, _slots.size() - 1)
	if _tween:
		_tween.kill()
	moving.emit()
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, float(i), snap_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(func() -> void: settled.emit(_index))
	if i != _index:
		_index = i
		selected.emit(i)

# --- input -------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _slots.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _tween:
				_tween.kill()
			_dragging = true
			moving.emit()
			_drag_distance = 0.0
			_velocity = 0.0
		elif _dragging:
			_dragging = false
			_release(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_distance += absf(event.relative.x)
		_velocity = event.velocity.x
		var delta := float (-event.relative.x) / spacing
		var last := float(_slots.size() - 1)
		# rubber-band when dragging past the first / last item
		if (_offset < 0.0 and delta < 0.0) or (_offset > last and delta > 0.0):
			delta *= 0.35
		_set_offset(_offset + delta)
		accept_event()

func _release(x: float) -> void:
	if _drag_distance < tap_threshold:
		# tap: pick whichever item is under the finger
		go_to(roundi(_offset + (x - size.x * 0.5) / spacing))
		return
	var projected := _offset - _velocity / spacing * flick_factor
	var target := roundi(projected)
	go_to(clampi(target, _index - 1, _index + 1))  # at most one step per swipe

# --- layout ------------------------------------------------------------

func _set_offset(value: float) -> void:
	_offset = value
	_layout()

func _layout() -> void:
	for i in _slots.size():
		var d := float(i) - _offset
		var t := clampf(absf(d), 0.0, 1.0)
		var s := lerpf(center_scale, side_scale, t)
		var slot := _slots[i]
		slot.scale = Vector2(s, s)
		slot.position = size * 0.5 - slot_size * 0.5 + Vector2(d * spacing, 0.0)
		slot.modulate.a = lerpf(1.0, side_alpha, t)
		slot.z_index = 1 if absf(d) < 0.5 else 0
		slot.visible = absf(d) < 2.5

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
