class_name PlayerSkins
extends RefCounted

## PlayerSkins — skin ownership/equip state, stored through SaveManager (InventoryData).
## Buying/unlocking is intentionally NOT here yet: add `grant(id)` later.

const SLOT: String = "skin"
const CATEGORY: String = "skins"

var _save: SaveManager

func _init(save: SaveManager) -> void:
	_save = save

func equipped_id() -> String:
	var inv: GameModels.InventoryData = _save.inventory_data if _save else null
	if inv == null:
		return SkinCatalog.DEFAULT_ID
	var id := str(inv.equipped.get(SLOT, ""))
	if id.is_empty() or not SkinCatalog.has_skin(id) or not is_owned(id):
		if inv.equipped.get(SLOT, "") != SkinCatalog.DEFAULT_ID and _save and _save.inventory:
			_save.inventory.mutate(func(d: GameModels.InventoryData) -> void:
				d.equipped[SLOT] = SkinCatalog.DEFAULT_ID
			)
		return SkinCatalog.DEFAULT_ID
	return id

func equipped_skin() -> Dictionary:
	return SkinCatalog.at(SkinCatalog.index_of(equipped_id()))

func is_owned(id: String) -> bool:
	if id == SkinCatalog.DEFAULT_ID:
		return true
	var inv: GameModels.InventoryData = _save.inventory_data if _save else null
	if inv == null:
		return false
	var owned: Array = inv.owned.get(CATEGORY, [])
	return id in owned

func equip(id: String) -> bool:
	if _save == null or not is_owned(id):
		return false
	_save.inventory.mutate(func(d: GameModels.InventoryData) -> void:
		d.equipped[SLOT] = id
	)
	if _save.profile:
		_save.profile.mutate(func(d: GameModels.ProfileData) -> void:
			d.current_character_id = id
		)
	_save.save_game()
	return true

func grant(id: String) -> bool:
	if _save == null or is_owned(id):
		return false
	_save.inventory.mutate(func(d: GameModels.InventoryData) -> void:
		var owned: Array = d.owned.get(CATEGORY, [])
		if not id in owned:
			owned.append(id)
		d.owned[CATEGORY] = owned
	)
	_save.save_game()
	return true

func unlock(id: String) -> bool:
	if _save == null:
		push_error("PlayerSkins: SaveManager is null.")
		return false
	if not SkinCatalog.has_skin(id):
		push_error(
			"PlayerSkins: Invalid character ID = " + id
		)
		return false
	# Already unlocked/owned.
	if is_owned(id):
		return true
	return grant(id)

func reset_to_default() -> void:
	if _save == null:
		return
	if _save.inventory:
		_save.inventory.mutate(func(d: GameModels.InventoryData) -> void:
			d.equipped[SLOT] = SkinCatalog.DEFAULT_ID
			d.owned[CATEGORY] = []
		)
	if _save.profile:
		_save.profile.mutate(func(d: GameModels.ProfileData) -> void:
			d.current_character_id = SkinCatalog.DEFAULT_ID
			d.character_progress = {}
		)
	_save.save_game()

func get_next_locked_skin() -> String:
	for s in SkinCatalog.SKINS:
		if not is_owned(s["id"]):
			return s["id"]
	return ""

static func resolve_equipped(save: SaveManager, progress: PlayerProgress) -> String:
	var skins := PlayerSkins.new(save)
	var id: String = skins.equipped_id()
	if id == SkinCatalog.DEFAULT_ID:
		return SkinCatalog.DEFAULT_ID
	if skins.is_owned(id):
		return id
	if progress and progress.is_character_unlocked(id):
		return id
	return SkinCatalog.DEFAULT_ID
