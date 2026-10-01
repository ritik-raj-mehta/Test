extends Camera2D
class_name CameraController

var goal_zoom := Vector2(1.3, 1.3)
var player: Player

var _drag_h := true
var _drag_v := true


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
	offset = Vector2(0, -400) 
	reset_smoothing()


func move_to_respawn(target: Vector2) -> void:
	if player == null:
		return
	player.global_position = target
	player.velocity = Vector2.ZERO


func zoom_to_goal() -> void:
	_save_drag()
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	zoom = goal_zoom


func reset_from_goal() -> void:
	zoom = Vector2.ONE
	offset = Vector2(0, -400)  # same value as in initialize
	_restore_drag()
	reset_smoothing()


func _save_drag() -> void:
	_drag_h = drag_horizontal_enabled
	_drag_v = drag_vertical_enabled


func _restore_drag() -> void:
	drag_horizontal_enabled = _drag_h
	drag_vertical_enabled = _drag_v
