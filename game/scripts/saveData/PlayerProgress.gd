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

	if current_character_id.is_empty():
		current_character_id = SkinCatalog.DEFAULT_ID

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

func activate_next_character() -> String:

	var current_index: int = (
		SkinCatalog.index_of(
			current_character_id
		)
	)

	var next_index: int = current_index + 1

	# --------------------------------------------------------
	# ALL CHARACTERS COMPLETED
	# --------------------------------------------------------

	if next_index >= SkinCatalog.count():

		print(
			"PLAYER PROGRESS | All characters completed."
		)

		return current_character_id

	# --------------------------------------------------------
	# GET NEXT CHARACTER
	# --------------------------------------------------------

	var next_character_id: String = (
		SkinCatalog.at(next_index)["id"]
	)

	# --------------------------------------------------------
	# ACTIVATE NEXT CHARACTER
	# --------------------------------------------------------

	current_character_id = next_character_id
	character_progress.profile_data.current_character_id = current_character_id
	character_progress.profile_repo.mark_dirty()
	print(
		"PLAYER PROGRESS | NEXT CHARACTER ACTIVATED = ",
		current_character_id
	)

	# --------------------------------------------------------
	# NOTIFY UI
	# --------------------------------------------------------

	if game_bus:
		game_bus.character_changed.emit(
			current_character_id
		)

	return current_character_id


func is_character_unlocked(character_id: String) -> bool:

	var index: int = SkinCatalog.index_of(character_id)

	# First character is always unlocked.
	if index == 0:
		return true

	if character_progress == null:
		return false

	# Previous character must be 40/40.
	var previous_id: String = str(
		SkinCatalog.at(index - 1).get("id", "")
	)

	if previous_id.is_empty():
		return false

	return (
		character_progress.get_progress(previous_id)
		>= CharacterProgress.REQUIRED_TAPS
	)
