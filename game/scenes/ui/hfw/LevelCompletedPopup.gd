class_name LevelCompletedPopup
extends CharacterPopup

@export var _content: Control
@export var _character: CharacterView
@export var _progress_bar: SkinProgress
@export var _home_button: BaseButton
@export var _next_button: BaseButton
@export var _retry_button: BaseButton

var _level: int = 0
var _progress_from: float = 0.0
var _progress_to: float = 0.0
var _result_received: bool = false

var _character_activation_started: bool = false
var _unlock_sequence_finished: bool = false
var _next_character_id: String = ""


func _on_ready() -> void:
	_show_equipped(_character)

	_on_press(_home_button, _on_home)
	_on_press(_next_button, _on_next)
	_on_press(_retry_button, _on_retry)

	if _content:
		UIAnim.pop_in(_content)
	if _next_button:
		_next_button.disabled = true


# ============================================================
# RESULT
# ============================================================

func show_result(level: int, progress_from: float = 0.0, progress_to: float = 0.0) -> void:
	_level = level
	_progress_from = progress_from
	_progress_to = clampf(
		float(_player_progress.get_current_progress())
		/ float(CharacterProgress.REQUIRED_TAPS),
		0.0, 1.0
	) if _player_progress else progress_to

	_result_received = true
	_character_activation_started = false
	_unlock_sequence_finished = false

	if _next_button:
		_next_button.disabled = true

	_next_character_id = _next_locked_character_id()
	_apply_next_badge(_progress_bar)

	_apply_result()


func _apply_result() -> void:
	if not _result_received:
		return
	if _progress_bar == null:
		push_error("LevelCompletedPopup: _progress_bar is NULL.")
		return

	_progress_bar.set_value_instant(_progress_from)
	_progress_bar.animate_to(_progress_from, _progress_to, 0.8)

	if _progress_to >= 1.0:
		_start_unlock_sequence()
	else:
		_unlock_sequence_finished = true
		if _next_button:
			_next_button.disabled = false


# ============================================================
# UNLOCK
# ============================================================

func _start_unlock_sequence() -> void:
	if _character_activation_started:
		return
	_character_activation_started = true
	_unlock_sequence_finished = false

	if _next_button:
		_next_button.disabled = true

	await get_tree().create_timer(0.8).timeout
	await _play_character_unlock_animation()

	_activate_next_character()

	_unlock_sequence_finished = true
	if _next_button:
		_next_button.disabled = false


func _play_character_unlock_animation() -> void:
	await get_tree().create_timer(0.4).timeout


func _activate_next_character() -> void:
	if _player_progress == null:
		push_error("LevelCompletedPopup: PlayerProgress is null.")
		return

	var activated: String = _player_progress.activate_next_character()

	if not _next_character_id.is_empty() and activated != _next_character_id:
		push_error(
			"LevelCompletedPopup: Wrong character activated. Expected = "
			+ _next_character_id + ", Got = " + activated
		)


# ============================================================
# NAVIGATION
# ============================================================

func _level_or_current() -> int:
	return _level if _level > 0 else (_save.get_level() if _save else 1)


func _wait_for_unlock() -> void:
	if _progress_to >= 1.0:
		while not _unlock_sequence_finished:
			await get_tree().process_frame


func _on_home() -> void:
	await close()
	_go(ScenePaths.GAMEPLAY)


func _on_next() -> void:
	await _wait_for_unlock()
	var next_level: int = _level_or_current() + 1
	await close()
	LevelLauncher.start(next_level, _scene, _save, _bus, _logger)


func _on_retry() -> void:
	await _wait_for_unlock()
	var level: int = _level_or_current()
	await close()
	LevelLauncher.start(level, _scene, _save, _bus, _logger)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		get_viewport().set_input_as_handled()
