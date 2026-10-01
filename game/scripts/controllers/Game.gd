extends Node2D
class_name Game

const RESET_GROUPS := [
	"obstacle", "falling_stone", "trigger_area", "boosters",
	"horizontal_zone_start", "horizontal_zone_end", "horizontal_zone_trigger",
]

var game_bus: Node
var player: Player
var goal: Goal
var camera: CameraController
var respawn_position: Vector2
var current_lvl_data: LevelData = null

var _initialized := false
var is_respawning := false
var is_level_completed := false


func initialize_game(
	p_game_bus: Node,
	lvl_data: LevelData,
	p_player: Player,
	p_goal: Goal,
	p_camera: CameraController
) -> void:
	if _initialized:
		return

	if p_game_bus == null or lvl_data == null or p_player == null or p_goal == null or p_camera == null:
		push_error("Game: missing dependency.")
		return

	game_bus = p_game_bus
	current_lvl_data = lvl_data
	player = p_player
	goal = p_goal
	camera = p_camera
	respawn_position = lvl_data.player_start
	_initialized = true

	player.setup(game_bus)
	goal.setup(game_bus)
	player.global_position = respawn_position
	camera.initialize(player, lvl_data)

	_connect_bus()


func _connect_bus() -> void:
	if not game_bus.player_died.is_connected(_on_player_died):
		game_bus.player_died.connect(_on_player_died)
	if not game_bus.goal_reached.is_connected(_on_goal_reached):
		game_bus.goal_reached.connect(_on_goal_reached)
	if not game_bus.goal_sequence_finished.is_connected(_on_goal_sequence_finished):
		game_bus.goal_sequence_finished.connect(_on_goal_sequence_finished)


func _on_player_died() -> void:
	if is_respawning or is_level_completed:
		return
	is_respawning = true

	player.global_position = respawn_position
	camera.move_to_respawn(respawn_position)
	player.reset_after_respawn()

	_reset_world()
	CameraDragState.reset()

	is_respawning = false
	if game_bus.has_signal("player_respawned"):
		game_bus.player_respawned.emit()


func _on_goal_reached(goal_player: Node2D, reached_goal: Node2D) -> void:
	if is_level_completed:
		return
	is_level_completed = true

	if goal_player.has_method("slow_down_at_goal"):
		goal_player.slow_down_at_goal(reached_goal)
	camera.zoom_to_goal()


func _on_goal_sequence_finished() -> void:
	game_bus.tap_tap_started.emit()


func reset_after_goal() -> void:
	is_level_completed = false
	is_respawning = false
	if goal:
		goal.reset()
	if player:
		player.global_position = respawn_position
		player.reset_after_respawn()
	if camera:
		camera.reset_from_goal()


func _reset_world() -> void:
	for group in RESET_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node.has_method("reset"):
				node.reset()
