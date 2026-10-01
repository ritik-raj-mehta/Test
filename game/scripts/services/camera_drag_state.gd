@tool
class_name CameraDragState

static var baseline_cached: bool = false
static var baseline_drag_left: float = 0.2
static var baseline_drag_right: float = 0.2
static var baseline_drag_top: float = 0.8
static var baseline_drag_bottom: float = 0.8
static var baseline_horiz_enabled: bool = true
static var baseline_vert_enabled: bool = true

static var active_target_drag_left: float = 0.2
static var active_target_drag_right: float = 0.2
static var active_target_drag_top: float = 0.8
static var active_target_drag_bottom: float = 0.8
static var active_horiz_enabled: bool = true
static var active_vert_enabled: bool = true

static var is_custom_mode: bool = false
static var active_player: Node2D = null
static var transition_speed: float = 3.0

static func reset() -> void:
	baseline_cached = false
	is_custom_mode = false
	active_player = null
	baseline_drag_left = 0.2
	baseline_drag_right = 0.2
	baseline_drag_top = 0.8
	baseline_drag_bottom = 0.8
	baseline_horiz_enabled = true
	baseline_vert_enabled = true

static func cache_baseline(cam: Camera2D) -> void:
	if not cam or baseline_cached:
		return
	baseline_drag_left = cam.drag_left_margin
	baseline_drag_right = cam.drag_right_margin
	baseline_drag_top = cam.drag_top_margin
	baseline_drag_bottom = cam.drag_bottom_margin
	baseline_horiz_enabled = cam.drag_horizontal_enabled
	baseline_vert_enabled = cam.drag_vertical_enabled
	baseline_cached = true

static func apply_start_zone(player: Node2D, left: float, right: float, top: float, bottom: float, horiz: bool, vert: bool, speed: float) -> void:
	if not player:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if not cam:
		return
	cache_baseline(cam)
	active_player = player
	transition_speed = speed
	active_target_drag_left = left
	active_target_drag_right = right
	active_target_drag_top = top
	active_target_drag_bottom = bottom
	active_horiz_enabled = horiz
	active_vert_enabled = vert
	is_custom_mode = true

	cam.drag_horizontal_enabled = horiz
	cam.drag_vertical_enabled = vert

static func apply_end_zone(player: Node2D, speed: float) -> void:
	if not player:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if not cam:
		return
	cache_baseline(cam)
	active_player = player
	transition_speed = speed
	active_target_drag_left = baseline_drag_left
	active_target_drag_right = baseline_drag_right
	active_target_drag_top = baseline_drag_top
	active_target_drag_bottom = baseline_drag_bottom
	active_horiz_enabled = baseline_horiz_enabled
	active_vert_enabled = baseline_vert_enabled
	is_custom_mode = false

static func update_camera_transition(delta: float) -> void:
	if not active_player or not is_instance_valid(active_player):
		return
	var cam: Camera2D = active_player.get_node_or_null("Camera2D")
	if not cam:
		return

	cam.drag_left_margin = lerp(cam.drag_left_margin, active_target_drag_left, delta * transition_speed)
	cam.drag_right_margin = lerp(cam.drag_right_margin, active_target_drag_right, delta * transition_speed)
	cam.drag_top_margin = lerp(cam.drag_top_margin, active_target_drag_top, delta * transition_speed)
	cam.drag_bottom_margin = lerp(cam.drag_bottom_margin, active_target_drag_bottom, delta * transition_speed)

	if not is_custom_mode:
		if abs(cam.drag_left_margin - baseline_drag_left) < 0.01 and abs(cam.drag_right_margin - baseline_drag_right) < 0.01:
			cam.drag_horizontal_enabled = baseline_horiz_enabled
			cam.drag_vertical_enabled = baseline_vert_enabled
			active_player = null
