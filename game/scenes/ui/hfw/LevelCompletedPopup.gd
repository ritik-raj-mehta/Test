class_name LevelCompletedPopup
extends AppView

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

	if _save:
		_character.set_skin(
			PlayerSkins.new(_save).equipped_skin()
		)

	_on_press(_home_button, _on_home)
	_on_press(_next_button, _on_next)
	_on_press(_retry_button, _on_retry)

	UIAnim.pop_in(_content)

	_apply_result()


func show_result(
	level: int,
	progress_from: float = 0.0,
	progress_to: float = 0.0
) -> void:

	print("========== LEVEL COMPLETE RESULT ==========")
	print("LEVEL: ", level)
	print("FROM: ", progress_from)
	print("TO: ", progress_to)
	print("PROGRESS BAR: ", _progress_bar)

	_level = level

	_progress_from = progress_from
	_progress_to = progress_to
	_result_received = true

	_apply_result()


func _apply_result() -> void:

	if not _result_received:
		return

	if _progress_bar == null:
		push_error(
			"LevelCompletedPopup: _progress_bar is NULL."
		)
		return

	print(
		"APPLYING PROGRESS: ",
		_progress_from,
		" -> ",
		_progress_to
	)

	_progress_bar.set_value_instant(
		_progress_from
	)

	_progress_bar.animate_to(
		_progress_from,
		_progress_to,
		0.8
	)


func _level_or_current() -> int:
	return _level if _level > 0 else (
		_save.get_level() if _save else 1
	)


func _on_home() -> void:
	await close()
	_go(ScenePaths.GAMEPLAY)


func _on_next() -> void:

	var next_level := _level_or_current() + 1

	await close()

	LevelLauncher.start(
		next_level,
		_scene,
		_save,
		_bus,
		_logger
	)


func _on_retry() -> void:

	var level := _level_or_current()

	await close()

	LevelLauncher.start(
		level,
		_scene,
		_save,
		_bus,
		_logger
	)


func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventScreenTouch:
		if event.pressed:
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.pressed:
			get_viewport().set_input_as_handled()
