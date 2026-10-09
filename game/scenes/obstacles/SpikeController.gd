@tool
extends ObstacleController
class_name SpikeController

const SPIKE_BASE_WIDTH: float = 46.0
const SPIKE_BASE_HEIGHT: float = 19.0

@export_range(1, 100, 1) var spike_count: int = 1:
	set(v):
		spike_count = maxi(1, v)
		update_components()

@export var wall_distance: float = 46.0:
	set(v):
		wall_distance = maxf(0.0, v)
		update_components()

@export_enum("Forward (+X):1", "Backward (-X):-1") var direction: int = 1:
	set(v):
		direction = 1 if v >= 0 else -1
		update_components()

@export var rotation_speed: float = 0.0:
	set(v):
		rotation_speed = v
		if not Engine.is_editor_hint():
			set_physics_process(rotation_speed != 0.0)

var is_lethal: bool = true

# Backward compatibility aliases
var count: int:
	get:
		return spike_count
	set(v):
		spike_count = v

var spacing: float:
	get:
		return wall_distance
	set(v):
		wall_distance = v

@onready var base_sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var base_col_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

# Node pools for high performance (zero allocations during gameplay)
var _sprites_pool: Array[Sprite2D] = []
var _col_shapes_pool: Array[CollisionShape2D] = []
var _shared_shape: RectangleShape2D = null
var _combined_shape: RectangleShape2D = null


func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	if not is_in_group("obstacle"):
		add_to_group("obstacle")
	if not is_in_group("obstacles"):
		add_to_group("obstacles")

	collision_layer = 2
	collision_mask = 0

	_ensure_base_references()
	update_components()

	if not Engine.is_editor_hint():
		set_physics_process(rotation_speed != 0.0)
	else:
		set_physics_process(false)


func _ensure_base_references() -> void:
	if base_sprite == null and has_node("Sprite2D"):
		base_sprite = get_node("Sprite2D") as Sprite2D
	if base_col_shape == null and has_node("CollisionShape2D"):
		base_col_shape = get_node("CollisionShape2D") as CollisionShape2D


func update_components() -> void:
	_ensure_base_references()
	_update_visuals()
	_update_collisions()

	if Engine.is_editor_hint():
		queue_redraw()


func _clean_legacy_children() -> void:
	for child in get_children():
		if child != base_sprite and child != base_col_shape:
			if child.name.begins_with("Sprite2D_") or child.name.begins_with("CollisionShape2D_"):
				child.queue_free()
				remove_child(child)


func _update_visuals() -> void:
	if not base_sprite:
		return

	_clean_legacy_children()

	# Base sprite at index 0
	base_sprite.position = Vector2.ZERO
	base_sprite.visible = true

	var needed_extra: int = spike_count - 1

	# Expand internal pool if needed
	while _sprites_pool.size() < needed_extra:
		var spr: Sprite2D = base_sprite.duplicate() as Sprite2D
		spr.name = "Sprite2D_%d" % (_sprites_pool.size() + 2)
		add_child(spr, false, Node.INTERNAL_MODE_BACK)
		_sprites_pool.append(spr)

	# Position active extra sprites and hide unused ones
	for i in range(_sprites_pool.size()):
		var spr: Sprite2D = _sprites_pool[i]
		if i < needed_extra:
			var idx: int = i + 1
			spr.position = Vector2(idx * wall_distance * direction, 0.0)
			spr.visible = true
		else:
			spr.visible = false


func _update_collisions() -> void:
	if not base_col_shape:
		return

	# If spikes are touching or overlapping (wall_distance <= SPIKE_BASE_WIDTH):
	# OPTIMIZATION: Combine into a SINGLE RectangleShape2D covering all spikes!
	if wall_distance <= SPIKE_BASE_WIDTH:
		for cs in _col_shapes_pool:
			cs.disabled = true
			cs.visible = false

		var total_width: float = (spike_count - 1) * wall_distance + SPIKE_BASE_WIDTH
		var center_x: float = (spike_count - 1) * wall_distance * direction * 0.5

		if _combined_shape == null:
			_combined_shape = RectangleShape2D.new()
		_combined_shape.size = Vector2(total_width, SPIKE_BASE_HEIGHT)

		base_col_shape.shape = _combined_shape
		base_col_shape.position = Vector2(center_x, 0.5)
		base_col_shape.disabled = false
		base_col_shape.visible = true
	else:
		# Separated spikes with gaps: each spike gets an individual shape sharing the same RectangleShape2D resource
		if _shared_shape == null:
			_shared_shape = RectangleShape2D.new()
			_shared_shape.size = Vector2(SPIKE_BASE_WIDTH, SPIKE_BASE_HEIGHT)

		base_col_shape.shape = _shared_shape
		base_col_shape.position = Vector2(0.0, 0.5)
		base_col_shape.disabled = false
		base_col_shape.visible = true

		var needed_extra: int = spike_count - 1
		while _col_shapes_pool.size() < needed_extra:
			var cs := CollisionShape2D.new()
			cs.name = "CollisionShape2D_%d" % (_col_shapes_pool.size() + 2)
			cs.shape = _shared_shape
			add_child(cs, false, Node.INTERNAL_MODE_BACK)
			_col_shapes_pool.append(cs)

		for i in range(_col_shapes_pool.size()):
			var cs: CollisionShape2D = _col_shapes_pool[i]
			if i < needed_extra:
				var idx: int = i + 1
				cs.position = Vector2(idx * wall_distance * direction, 0.5)
				cs.disabled = false
				cs.visible = true
			else:
				cs.disabled = true
				cs.visible = false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if rotation_speed != 0.0:
		rotation += rotation_speed * delta


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
	if not is_in_editor() or spike_count <= 1:
		return

	var total_w: float = (spike_count - 1) * wall_distance * direction
	draw_line(Vector2(0, 10), Vector2(total_w, 10), Color(1.0, 0.3, 0.3, 0.6), 1.5)
