class_name CharacterPopup
extends AppView


var _player_progress: PlayerProgress


func inject_services(registry: Node) -> void:
	super.inject_services(registry)

	_player_progress = registry.get_service(
		&"player_progress"
	) as PlayerProgress

	if _player_progress == null:
		push_error(
			"%s: PlayerProgress service not found."
			% name
		)


# ============================================================
# EQUIPPED CHARACTER VISUAL
# ============================================================

func _show_equipped(view: CharacterView) -> void:
	if view == null:
		return

	var id: String = PlayerSkins.resolve_equipped(
		_save,
		_player_progress
	)

	view.set_skin(
		SkinCatalog.get_skin(id)
	)


# ============================================================
# CURRENT PROGRESSION CHARACTER
# Used by the progress badge — shows the character the player
# is actively working to unlock right now.
# ============================================================

func _next_locked_character_id() -> String:
	if _player_progress == null:
		return ""

	# In the current design current_character_id IS the character
	# being unlocked, so it's also the badge target.
	return _player_progress.get_current_character_id()


# ============================================================
# NEXT CHARACTER
# Returns the character immediately after the currently active
# progression character. Used to check whether there is a
# character to advance to after the current one completes.
# ============================================================

func _next_character_id() -> String:
	if _player_progress == null:
		return ""

	var current_id: String = (
		_player_progress.get_current_character_id()
	)

	if current_id.is_empty():
		return ""

	var current_index: int = (
		SkinCatalog.index_of(current_id)
	)

	var next_index: int = current_index + 1

	if next_index >= SkinCatalog.count():
		return ""

	var next_id: String = str(
		SkinCatalog.at(next_index).get("id", "")
	)

	return next_id


# ============================================================
# PROGRESS BADGE
# ============================================================

func _apply_next_badge(bar: SkinProgress) -> void:
	# The badge shows the character currently being progressed
	# toward unlock — that is always current_character_id.
	var id: String = _next_locked_character_id()

	if bar == null or id.is_empty() or id == SkinCatalog.DEFAULT_ID:
		return

	bar.set_badge_skin(
		SkinCatalog.get_skin(id)
	)
