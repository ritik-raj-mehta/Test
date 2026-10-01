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
	return id if SkinCatalog.has_skin(id) else SkinCatalog.DEFAULT_ID

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
	_save.save_game()
	return true
