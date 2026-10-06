class_name PlayerProgress
extends RefCounted


var character_progress: CharacterProgress
var game_bus: GameBus


var current_character_id: String = (
	SkinCatalog.DEFAULT_ID
)


# ============================================================
# INITIALIZE
# ============================================================

func initialize(
	save: SaveManager,
	bus: GameBus
) -> void:

	if save == null:

		push_error(
			"PlayerProgress: SaveManager is null."
		)

		return


	if bus == null:

		push_error(
			"PlayerProgress: GameBus is null."
		)

		return


	game_bus = bus


	character_progress = CharacterProgress.new()

	character_progress.initialize(save)
	# Load the active character from saved profile.
	current_character_id = character_progress.profile_data.current_character_id

	# Zumpa (index 0) is always free — it should never be the progression
	# target. If no value was saved (or an old save stored zumpa), find the
	# first character whose own tap-progress hasn't reached the cap yet.
	if current_character_id.is_empty() or current_character_id == SkinCatalog.DEFAULT_ID:
		current_character_id = _find_first_unlocked_progression_target()

	print(
		"PLAYER PROGRESS INITIALIZED | Current character: ",
		current_character_id
	)


# ============================================================
# CURRENT CHARACTER
# ============================================================

func get_current_character_id() -> String:

	return current_character_id


# ============================================================
# CURRENT CHARACTER PROGRESS
# ============================================================

func get_current_progress() -> int:

	if character_progress == null:

		return 0


	return character_progress.get_progress(
		current_character_id
	)


# ============================================================
# ADD PROGRESS
# ============================================================

func add_progress(
	amount: int = 1
) -> int:
	if character_progress == null:
		return 0
	var value := character_progress.add_progress(current_character_id,amount)
	print(
		"PLAYER PROGRESS | ",
		current_character_id,
		" = ",
		value,
		"/",
		CharacterProgress.REQUIRED_TAPS
	)
	if value >= CharacterProgress.REQUIRED_TAPS:
		_on_character_completed()
	return value

# ============================================================
# CHARACTER COMPLETED
# ============================================================

func _on_character_completed() -> void:

	print(
		"CHARACTER COMPLETED | ",
		current_character_id
	)

	# Tell the rest of the game that the current
	# character has reached 100%.

	if game_bus:
		game_bus.character_completed.emit(
			current_character_id
		)

	# IMPORTANT:
	# DO NOT CHANGE current_character_id HERE.
	#
	# The completed character must remain active
	# until LevelCompletedPopup finishes its animation.

# ============================================================
# FIND FIRST PROGRESSION TARGET
# Returns the first character (after zumpa) that hasn't
# completed its own 40-tap progression yet.
# ============================================================

func _find_first_unlocked_progression_target() -> String:
	for i in range(1, SkinCatalog.count()):
		var candidate_id: String = str(
			SkinCatalog.at(i).get("id", "")
		)
		if candidate_id.is_empty():
			continue
		if not _is_character_completed(candidate_id):
			return candidate_id
	# All characters completed — stay on the last one.
	var last := SkinCatalog.at(SkinCatalog.count() - 1)
	return str(last.get("id", SkinCatalog.DEFAULT_ID))


func activate_next_locked_character_after(
	unlocked_character_id: String
) -> String:

	if character_progress == null:
		push_error("PlayerProgress: CharacterProgress is null.")
		return current_character_id

	var unlocked_index: int = (
		SkinCatalog.index_of(unlocked_character_id)
	)

	for i in range(
		unlocked_index + 1,
		SkinCatalog.count()
	):
		var candidate_id: String = str(
			SkinCatalog.at(i).get("id", "")
		)

		if candidate_id.is_empty():
			continue

		# First character whose own progress is still below the cap.
		if not _is_character_completed(candidate_id):
			current_character_id = candidate_id

			character_progress.profile_data.current_character_id = (
				current_character_id
			)

			character_progress.profile_repo.mark_dirty()

			print(
				"PLAYER PROGRESS | NEXT LOCKED CHARACTER = ",
				current_character_id
			)

			if game_bus:
				game_bus.character_changed.emit(
					current_character_id
				)

			return current_character_id

	print(
		"PLAYER PROGRESS | No more locked characters."
	)

	return current_character_id

func is_all_characters_completed() -> bool:
	for i in range(1, SkinCatalog.count()):
		var cid: String = str(
			SkinCatalog.at(i).get("id", "")
		)
		if cid.is_empty():
			continue
		if not _is_character_completed(cid):
			return false
	return true


func _is_character_completed(character_id: String) -> bool:
	if character_progress == null:
		return false

	return (
		character_progress.get_progress(character_id)
		>= CharacterProgress.REQUIRED_TAPS
	)


func is_character_unlocked(character_id: String) -> bool:

	var index: int = SkinCatalog.index_of(character_id)

	# Zumpa (index 0) is always unlocked.
	if index == 0:
		return true

	if character_progress == null:
		return false

	# A character is unlocked only when its OWN tap-progress has reached
	# the required cap. Each character must be individually progressed.
	return (
		character_progress.get_progress(character_id)
		>= CharacterProgress.REQUIRED_TAPS
	)
