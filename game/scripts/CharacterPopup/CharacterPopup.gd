class_name CharacterPopup
extends AppView

var _player_progress: PlayerProgress


func inject_services(registry: Node) -> void:
	super.inject_services(registry)
	_player_progress = registry.get_service(&"player_progress") as PlayerProgress
	if _player_progress == null:
		push_error("%s: PlayerProgress service not found." % name)


func _show_equipped(view: CharacterView) -> void:
	if view == null:
		return
	var id: String = PlayerSkins.resolve_equipped(_save, _player_progress)
	view.set_skin(SkinCatalog.get_skin(id))


func _next_locked_character_id() -> String:
	if _player_progress == null:
		return ""
	var current_id: String = _player_progress.get_current_character_id()
	if current_id.is_empty():
		return ""
	for i in range(SkinCatalog.index_of(current_id) + 1, SkinCatalog.count()):
		var id: String = str(SkinCatalog.at(i).get("id", ""))
		if id.is_empty():
			continue
		if _player_progress.character_progress.get_progress(id) < CharacterProgress.REQUIRED_TAPS:
			return id
	return ""


func _apply_next_badge(bar: SkinProgress) -> void:
	var id: String = _next_locked_character_id()
	if bar and not id.is_empty():
		bar.set_badge_skin(SkinCatalog.get_skin(id))
