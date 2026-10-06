extends Line2D
class_name Trails

var queue: Array[Vector2] = []
var active: bool = true

@export var max_length: int = 20


func _process(_delta: float) -> void:
	if not active:
		return
	var pos := _get_position()
	queue.push_front(pos)
	if queue.size() > max_length:
		queue.pop_back()
	clear_points()
	for point in queue:
		add_point(to_local(point))


func _get_position() -> Vector2:
	return get_parent().global_position


func reset_trail() -> void:
	queue.clear()
	clear_points()


func stop_trail() -> void:
	active = false
	reset_trail()
	hide()


func start_trail() -> void:
	reset_trail()
	show()
	active = true
