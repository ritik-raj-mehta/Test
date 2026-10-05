class_name TapTapPopup
extends CharacterPopup

signal progress_changed(value: float)

@export var character_id: String = ""
@export var rays_speed: float = 0.12

@onready var _rays: Control = %Rays
@onready var _tap_area: Control = %TapArea
@onready var _character: CharacterView = %Character
@onready var _progress_bar: SkinProgress = %Progress
@onready var _ring_progress: RingProgress = %CountDownProgress

var _current_progress: int = 0
var _progress_before: float = 0.0
var _progress_after: float = 0.0
var _character_completed: bool = false
var _completion_sent: bool = false


func inject_services(registry: Node) -> void:
	super.inject_services(registry)
	if _bus and not _bus.character_changed.is_connected(_on_character_changed):
		_bus.character_changed.connect(_on_character_changed)


func _on_ready() -> void:
	call_deferred("_initialize_popup")


func _process(delta: float) -> void:
	if _rays:
		_rays.rotation += rays_speed * delta


# ============================================================
# PROGRESS HELPERS
# ============================================================

func _progress_ratio() -> float:
	return clampf(
		float(_current_progress) / float(CharacterProgress.REQUIRED_TAPS),
		0.0, 1.0
	)


# Reads saved progress and snaps the bar to it (no animation from 0).
func _load_progress() -> void:
	_current_progress = _player_progress.get_current_progress() if _player_progress else 0
	var progress := _progress_ratio()
	_progress_before = progress
	_progress_after = progress
	if _progress_bar:
		_progress_bar.set_value_instant(progress)


# ============================================================
# INIT / OPEN
# ============================================================

func _initialize_popup() -> void:
	_character_completed = false
	_completion_sent = false

	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is not available.")
	else:
		character_id = _player_progress.get_current_character_id()
		_show_equipped(_character)
		_apply_next_badge(_progress_bar)
		_load_progress()

	if _tap_area:
		_bind_tap(_tap_area, _on_tap)
	else:
		push_error("TapTapPopup: _tap_area is not assigned.")

	if _ring_progress:
		if not _ring_progress.countdown_finished.is_connected(_on_countdown_finished):
			_ring_progress.countdown_finished.connect(_on_countdown_finished)
		_ring_progress.start_countdown()
	else:
		push_error("TapTapPopup: RingProgress is not assigned.")


func prepare_for_open() -> void:
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return

	_character_completed = false
	_completion_sent = false

	character_id = _player_progress.get_current_character_id()
	_show_equipped(_character)
	_apply_next_badge(_progress_bar)
	_load_progress()


# Kept in case something outside still calls it.
func initialize_progress() -> void:
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return
	character_id = _player_progress.get_current_character_id()
	_load_progress()


# ============================================================
# TAP
# ============================================================

func _on_tap() -> void:
	if _character_completed:
		return
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return
	if character_id.is_empty():
		push_error("TapTapPopup: character_id is empty.")
		return

	_current_progress = _player_progress.add_progress(1)
	var progress := _progress_ratio()
	_progress_after = progress

	if _save:
		var result := _save.save_game()
		if result != null and not result.success:
			push_error("Failed to save character progress: " + result.error_message)

	if _haptics:
		_haptics.light()

	if _progress_bar:
		_progress_bar.animate_to(_progress_bar.get_value(), progress, 0.15)

	if _character:
		_character.bounce()

	progress_changed.emit(progress)

	# Completion is sent immediately, not after the countdown.
	if _current_progress >= CharacterProgress.REQUIRED_TAPS:
		_character_completed = true
		if not _completion_sent:
			_completion_sent = true
			if _bus:
				_bus.tap_tap_completed.emit(_progress_before, _progress_after)
			else:
				push_error("TapTapPopup: GameBus is NULL.")


# ============================================================
# EVENTS
# ============================================================

func _on_character_changed(new_character_id: String) -> void:
	_character_completed = false
	_completion_sent = false
	character_id = new_character_id

	_show_equipped(_character)
	_apply_next_badge(_progress_bar)
	_load_progress()

	progress_changed.emit(_progress_ratio())


func _on_countdown_finished() -> void:
	# Countdown never completes a character that already finished.
	if _character_completed:
		return
	if _bus:
		_bus.tap_tap_completed.emit(_progress_before, _progress_after)
