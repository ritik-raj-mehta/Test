extends Camera2D
class_name CameraController


# ============================================================
# CAMERA
# ============================================================

var goal_zoom := Vector2(1.3, 1.3)
var player: Player

var _drag_h := true
var _drag_v := true

const BOTTOM_MARGIN := 560.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_on_ready()


func _on_ready() -> void:
	get_viewport().size_changed.connect(_refresh_offset)


# ============================================================
# NORMAL CAMERA OFFSET
# ============================================================

func _refresh_offset() -> void:
	var h: float = get_viewport_rect().size.y / zoom.y

	offset = Vector2(
		0,
		-(h * 0.5 - BOTTOM_MARGIN)
	)


# ============================================================
# INITIALIZE
# ============================================================

func initialize(target_player: Player, lvl_data: LevelData) -> void:
	if target_player == null or lvl_data == null:
		push_error("CameraController: missing player or level data.")
		return

	player = target_player
	goal_zoom = lvl_data.goal_zoom

	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = true
	position_smoothing_speed = lvl_data.camera_follow_speed

	drag_horizontal_enabled = lvl_data.camera_drag_horizontal_enabled
	drag_vertical_enabled = lvl_data.camera_drag_vertical_enabled

	drag_horizontal_offset = lvl_data.camera_drag_horizontal_offset
	drag_vertical_offset = lvl_data.camera_drag_vertical_offset

	drag_left_margin = lvl_data.camera_drag_left_margin
	drag_top_margin = lvl_data.camera_drag_top_margin
	drag_right_margin = lvl_data.camera_drag_right_margin
	drag_bottom_margin = lvl_data.camera_drag_bottom_margin

	_refresh_offset()
	reset_smoothing()


# ============================================================
# RESPAWN
# ============================================================

func move_to_respawn(target: Vector2) -> void:
	if player == null:
		return

	if _is_zoomed_to_goal:
		reset_from_goal()

	player.global_position = target
	player.velocity = Vector2.ZERO


var _goal_tween: Tween = null
var _is_zoomed_to_goal: bool = false


func zoom_to_goal(goal_target: Node2D = null, duration: float = 1.35) -> void:
	if player == null:
		return

	_save_drag()

	# Disable drag so the camera can smoothly center on the goal.
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

	var target_pos: Vector2 = player.global_position
	if goal_target != null:
		if goal_target.has_method("get_goal_position"):
			target_pos = goal_target.call("get_goal_position")
		else:
			target_pos = goal_target.global_position

	# Ensure a deeper dramatic zoom on the fruit
	var target_zoom := Vector2(
		maxf(goal_zoom.x, 2.4),
		maxf(goal_zoom.y, 2.4)
	)

	if _goal_tween and _goal_tween.is_valid():
		_goal_tween.kill()

	_is_zoomed_to_goal = true
	top_level = true
	global_position = player.global_position

	_goal_tween = create_tween().set_parallel(true)
	_goal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_goal_tween.tween_property(self, "global_position", target_pos, duration)
	_goal_tween.tween_property(self, "offset", Vector2.ZERO, duration)
	_goal_tween.tween_property(self, "zoom", target_zoom, duration)


# ============================================================
# RESET AFTER GOAL
# ============================================================

func reset_from_goal() -> void:
	if _goal_tween and _goal_tween.is_valid():
		_goal_tween.kill()

	_is_zoomed_to_goal = false
	top_level = false
	position = Vector2.ZERO
	zoom = Vector2.ONE

	_refresh_offset()

	_restore_drag()

	reset_smoothing()


# ============================================================
# DRAG SETTINGS
# ============================================================

func _save_drag() -> void:
	_drag_h = drag_horizontal_enabled
	_drag_v = drag_vertical_enabled


func _restore_drag() -> void:
	drag_horizontal_enabled = _drag_h
	drag_vertical_enabled = _drag_v


# ============================================================
# SCREEN SHAKE
# ============================================================

func shake(strength: float = 6.0, duration: float = 0.16) -> void:
	var base_offset := offset
	var tw := create_tween()
	tw.tween_method(func(factor: float) -> void:
		offset = base_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (strength * factor)
	, 1.0, 0.0, duration)
	tw.tween_callback(func() -> void:
		offset = base_offset
	)
