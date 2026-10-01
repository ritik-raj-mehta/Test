class_name TapTapPopup
extends AppView


signal progress_changed(value: float)


# ============================================================
# CONFIG
# ============================================================

@export var character_id: String = ""
@export var taps_required: int = 40
@export var rays_speed: float = 0.12


# ============================================================
# UI
# ============================================================

@onready var _rays: Control = %Rays
@onready var _tap_area: Control = %TapArea
@onready var _character: CharacterView = %Character
@onready var _progress_bar: SkinProgress = %Progress
@onready var _ring_progress: RingProgress = %CountDownProgress


# ============================================================
# PROGRESS
# ============================================================

var _player_progress: PlayerProgress
var _character_progress: CharacterProgress

var _current_progress: int = 0

var _progress_before: float = 0.0
var _progress_after: float = 0.0


# ============================================================
# SERVICE INJECTION
# ============================================================

func inject_services(registry: Node) -> void:

	super.inject_services(registry)

	_player_progress = registry.get_service(
		&"player_progress"
	) as PlayerProgress

	if _player_progress:

		_character_progress = (
			_player_progress.character_progress
		)

		print(
			"TapTapPopup: PlayerProgress injected."
		)

		print(
			"TapTapPopup: CharacterProgress = ",
			_character_progress
		)

	else:

		push_error(
			"TapTapPopup: PlayerProgress service not found."
		)


# ============================================================
# READY
# ============================================================

func _on_ready() -> void:

	call_deferred(
		"_initialize_popup"
	)


# ============================================================
# SELF INITIALIZATION
# ============================================================

func _initialize_popup() -> void:

	print(
		"========== TAP TAP INITIALIZE =========="
	)


	# --------------------------------------------------------
	# CHARACTER
	# --------------------------------------------------------

	if _save:

		var player_skins := PlayerSkins.new(
			_save
		)

		character_id = (
			player_skins.equipped_id()
		)

		print(
			"TapTapPopup Character ID: ",
			character_id
		)

		if _character:

			_character.set_skin(
				player_skins.equipped_skin()
			)

	else:

		push_error(
			"TapTapPopup: SaveManager is not available."
		)


	# --------------------------------------------------------
	# PROGRESS BAR
	# --------------------------------------------------------

	if _progress_bar:

		_progress_bar.set_value_instant(
			0.0
		)

	else:

		push_error(
			"TapTapPopup: Progress bar is not assigned."
		)


	# --------------------------------------------------------
	# TAP AREA
	# --------------------------------------------------------

	if _tap_area:

		_bind_tap(
			_tap_area,
			_on_tap
		)

	else:

		push_error(
			"TapTapPopup: _tap_area is not assigned."
		)


	# --------------------------------------------------------
	# COUNTDOWN
	# --------------------------------------------------------

	if _ring_progress:

		if not _ring_progress.countdown_finished.is_connected(
			_on_countdown_finished
		):

			_ring_progress.countdown_finished.connect(
				_on_countdown_finished
			)

		print(
			"TapTapPopup: Starting 3 second countdown."
		)

		_ring_progress.start_countdown()

	else:

		push_error(
			"TapTapPopup: RingProgress is not assigned."
		)


	# --------------------------------------------------------
	# LOAD SAVED CHARACTER PROGRESS
	# --------------------------------------------------------

	initialize_progress()


	print(
		"========== TAP TAP INITIALIZED =========="
	)


# ============================================================
# INITIALIZE SAVED PROGRESS
# ============================================================

func initialize_progress() -> void:

	if _character_progress == null:

		push_error(
			"TapTapPopup: CharacterProgress is null."
		)

		return


	if character_id.is_empty():

		push_error(
			"TapTapPopup: character_id is empty."
		)

		return


	_current_progress = (
		_character_progress.get_progress(
			character_id
		)
	)


	var progress := (
		float(_current_progress)
		/
		float(maxi(1, taps_required))
	)

	progress = clampf(
		progress,
		0.0,
		1.0
	)


	_progress_before = progress
	_progress_after = progress


	_update_progress_bar()


	print(
		"CHARACTER PROGRESS | ",
		character_id,
		" = ",
		_current_progress,
		"/",
		taps_required
	)


# ============================================================
# UPDATE PROGRESS BAR
# ============================================================

func _update_progress_bar() -> void:

	if _progress_bar == null:
		return


	var progress := (
		float(_current_progress)
		/
		float(maxi(1, taps_required))
	)

	progress = clampf(
		progress,
		0.0,
		1.0
	)


	_progress_bar.set_value_instant(
		progress
	)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if _rays:

		_rays.rotation += (
			rays_speed * delta
		)


# ============================================================
# TAP
# ============================================================

func _on_tap() -> void:

	# Taps ONLY update character progress.
	# They do NOT control the popup lifetime.

	if _character_progress == null:

		push_error(
			"TapTapPopup: CharacterProgress is null."
		)

		return


	if character_id.is_empty():

		push_error(
			"TapTapPopup: character_id is empty."
		)

		return


	# --------------------------------------------------------
	# ADD CHARACTER PROGRESS
	# --------------------------------------------------------

	_current_progress = (
		_character_progress.add_progress(
			character_id,
			1
		)
	)


	# --------------------------------------------------------
	# CALCULATE PROGRESS
	# --------------------------------------------------------

	var progress := (
		float(_current_progress)
		/
		float(maxi(1, taps_required))
	)

	progress = clampf(
		progress,
		0.0,
		1.0
	)


	_progress_after = progress


	# --------------------------------------------------------
	# SAVE
	# --------------------------------------------------------

	if _save:

		var result := _save.save_game()

		if result != null and not result.success:

			push_error(
				"Failed to save character progress: "
				+ result.error_message
			)


	# --------------------------------------------------------
	# HAPTICS
	# --------------------------------------------------------

	if _haptics:

		_haptics.light()


	# --------------------------------------------------------
	# PROGRESS BAR
	# --------------------------------------------------------

	if _progress_bar:

		_progress_bar.animate_to(
			_progress_bar.get_value(),
			progress,
			0.15
		)


	# --------------------------------------------------------
	# CHARACTER ANIMATION
	# --------------------------------------------------------

	if _character:

		_character.bounce()


	# --------------------------------------------------------
	# UI SIGNAL ONLY
	# --------------------------------------------------------

	progress_changed.emit(
		progress
	)


	print(
		"CHARACTER UPDATED | ",
		character_id,
		" = ",
		_current_progress,
		"/",
		taps_required
	)


# ============================================================
# COUNTDOWN FINISHED
# ============================================================

func _on_countdown_finished() -> void:

	print(
		"TapTapPopup: 3 seconds finished."
	)

	if _bus == null:

		push_error(
			"TapTapPopup: GameBus is not available."
		)

		return


	# --------------------------------------------------------
	# GAME-LEVEL EVENT
	# --------------------------------------------------------

	_bus.tap_tap_completed.emit(
		_progress_before,
		_progress_after
	)
