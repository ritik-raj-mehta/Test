class_name WorldCarousel
extends Control

## Snap carousel of WORLD cards: current world is centred, only one page visible at a time
## (previous/next peek slightly at the edges). Works with arrow buttons (previous()/next()),
## mouse/touch drag, and tap on a peeking neighbour.
##
## One `card_scene` is instanced per world and populated via card.set_world(world_dict, index)
## if the card has that method (WorldCard.gd implements it).

signal selected(index: int)   ## snap target changed (fires immediately)
signal moving()               ## drag started or a snap animation started
signal settled(index: int)    ## carousel came to rest on `index`

@export var card_scene: PackedScene  ## defaults to WorldCard.tscn if left empty
@export var card_size: Vector2 = Vector2(600, 300)
@export var side_scale: float = 0.9
@export var side_alpha: float = 0.5
@export var tap_threshold: float = 12.0
@export var snap_time: float = 0.28
@export var flick_factor: float = 0.15

const DEFAULT_CARD := preload("res://game/scenes/Worlds/WorldCard.tscn")

var _slots: Array[Control] = []
var _cards: Array[Control] = []
var spacing: float = 0.0
var _offset: float = 0.0
var _index: int = 0
var _tween: Tween
var _dragging: bool = false
var _drag_distance: float = 0.0
var _velocity: float = 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)

## worlds: Array of world Dictionaries (WorldCatalog.at(i)).
func build(worlds: Array, start_index: int = 0) -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	_cards.clear()

	var scene := card_scene if card_scene != null else DEFAULT_CARD
	for i in worlds.size():
		var slot := Control.new()
		slot.custom_minimum_size = card_size
		slot.size = card_size
		slot.pivot_offset = card_size * 0.5
		var card := scene.instantiate() as Control
		slot.add_child(card)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(slot)
		_ignore_mouse(slot)
		_slots.append(slot)
		_cards.append(card)
		if card.has_method("set_world"):
			card.set_world(worlds[i], i)

	spacing = size.x  # one full page per world
	_index = clampi(start_index, 0, maxi(_slots.size() - 1, 0))
	_offset = float(_index)
	_layout()

func card_at(i: int) -> Control:
	return _cards[i]

func current_index() -> int:
	return _index

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
	if _slots.is_empty() or spacing <= 0.0:
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
		var delta :float= -event.relative.x / spacing
		var last := float(_slots.size() - 1)
		if (_offset < 0.0 and delta < 0.0) or (_offset > last and delta > 0.0):
			delta *= 0.35
		_set_offset(_offset + delta)
		accept_event()

func _release(x: float) -> void:
	if _drag_distance < tap_threshold:
		go_to(roundi(_offset + (x - size.x * 0.5) / spacing))
		return
	var projected := _offset - _velocity / spacing * flick_factor
	var target := roundi(projected)
	go_to(clampi(target, _index - 1, _index + 1))

# --- layout ------------------------------------------------------------

func _set_offset(value: float) -> void:
	_offset = value
	_layout()

func _layout() -> void:
	spacing = size.x
	for i in _slots.size():
		var d := float(i) - _offset
		var t := clampf(absf(d), 0.0, 1.0)
		var s := lerpf(1.0, side_scale, t)
		var slot := _slots[i]
		slot.scale = Vector2(s, s)
		slot.position = size * 0.5 - card_size * 0.5 + Vector2(d * spacing, 0.0)
		slot.modulate.a = lerpf(1.0, side_alpha, t)
		slot.z_index = 1 if absf(d) < 0.5 else 0
		slot.visible = absf(d) < 1.5

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
