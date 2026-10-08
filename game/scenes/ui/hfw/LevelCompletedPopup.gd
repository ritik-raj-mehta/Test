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


func _on_ready() -> void:
	uses_backdrop = true
	_show_equipped(_character)

	# --------------------------------------------------------
	# BUTTONS
	# --------------------------------------------------------
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

func show_result(
	level: int,
	progress_from: float = 0.0,
	progress_to: float = 0.0
) -> void:
	_level = level

	_result_received = true

	if _next_button:
		_next_button.disabled = false

	# Hide progress bar if all characters are already unlocked
	if _player_progress and _player_progress.is_all_characters_completed():
		if _progress_bar:
			_progress_bar.visible = false
	else:
		if _progress_bar:
			_progress_bar.visible = true

		# Progress badge continues to use the progression character.
		_apply_next_badge(_progress_bar)

		# If progress_to >= 1.0, the previous character was just unlocked/completed
		# and progression has moved to the NEXT character.
		# Show the NEXT character's current progress instead of 100%.
		if progress_to >= 1.0 and _player_progress:
			var current_taps := _player_progress.get_current_progress()
			var next_ratio := clampf(
				float(current_taps) / float(CharacterProgress.REQUIRED_TAPS),
				0.0, 1.0
			)
			_progress_from = next_ratio
			_progress_to = next_ratio
		elif (progress_to <= 0.0 or progress_from <= 0.0) and _player_progress:
			var current_taps := _player_progress.get_current_progress()
			var curr_ratio := clampf(
				float(current_taps) / float(CharacterProgress.REQUIRED_TAPS),
				0.0, 1.0
			)
			_progress_from = curr_ratio
			_progress_to = curr_ratio
		else:
			_progress_from = clampf(progress_from, 0.0, 1.0)
			_progress_to = clampf(progress_to, 0.0, 1.0)

	# Character visual uses the equipped character.
	_show_equipped(_character)

	_apply_result()


# ============================================================
# APPLY RESULT
# ============================================================

func _apply_result() -> void:
	if not _result_received:
		return

	if _progress_bar == null:
		push_error(
			"LevelCompletedPopup: _progress_bar is NULL."
		)
		return

	_progress_bar.set_value_instant(
		_progress_from
	)

	_progress_bar.animate_to(
		_progress_from,
		_progress_to,
		0.8
	)

	if _next_button:
		_next_button.disabled = false


# ============================================================
# NAVIGATION
# ============================================================

func _level_or_current() -> int:
	return (
		_level
		if _level > 0
		else (_save.get_level() if _save else 1)
	)


func _on_home() -> void:
	await close()

	_go(ScenePaths.GAMEPLAY)


func _on_next() -> void:
	var next_level: int = (
		_level_or_current() + 1
	)

	await close()

	LevelLauncher.start(
		next_level,
		_scene,
		_save,
		_bus,
		_logger
	)


func _on_retry() -> void:
	var level: int = _level_or_current()

	await close()

	LevelLauncher.start(
		level,
		_scene,
		_save,
		_bus,
		_logger
	)


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventScreenTouch
		or event is InputEventMouseButton
	) and event.pressed:
		get_viewport().set_input_as_handled()
