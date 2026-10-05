class_name CharacterProgress
extends RefCounted


var profile_data: GameModels.ProfileData
var profile_repo: BaseRepository


const REQUIRED_TAPS: int = 40


func initialize(save: SaveManager) -> void:

	if save == null:
		push_error(
			"CharacterProgress: SaveManager is null."
		)
		return

	profile_data = save.profile_data
	profile_repo = save.profile

	print(
		"CharacterProgress initialized."
	)


func get_progress(character_id: String) -> int:

	if profile_data == null:
		return 0

	return int(
		profile_data.character_progress.get(
			character_id,
			0
		)
	)


func add_progress(
	character_id: String,
	amount: int = 1
) -> int:

	if profile_data == null:

		push_error(
			"CharacterProgress: ProfileData is null."
		)

		return 0


	if profile_repo == null:

		push_error(
			"CharacterProgress: ProfileRepository is null."
		)

		return 0


	if amount <= 0:

		return get_progress(
			character_id
		)


	var current := get_progress(
		character_id
	)

	current += amount

	current = mini(
		current,
		REQUIRED_TAPS
	)


	profile_data.character_progress[
		character_id
	] = current


	profile_repo.mark_dirty()


	print(
		"CHARACTER UPDATED | ",
		character_id,
		" = ",
		current,
		"/",
		REQUIRED_TAPS
	)


	return current
