class_name PlayerProgress
extends RefCounted


var character_progress: CharacterProgress


func initialize(save: SaveManager) -> void:
	if save == null:
		push_error("PlayerProgress: SaveManager is null.")
		return

	var profile := save.profile_data

	print("========== PLAYER PROFILE DEBUG ==========")
	print("Profile object: ", profile)
	print("Profile script: ", profile.get_script())
	print("Profile script path: ", profile.get_script().resource_path)

	for property in profile.get_script().get_script_property_list():
		print("PROPERTY: ", property.name)

	print("fruit_progress value: ", profile.get("fruit_progress"))
	print("==========================================")

	character_progress = CharacterProgress.new()
	character_progress.initialize(save)
