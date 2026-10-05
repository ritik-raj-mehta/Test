class_name SkinsScene
extends AppView

## SkinsScene — swipe/drag or use the arrows to browse skins, press Select to equip.
## Characters unlock according to PlayerProgress.
##
## Unlock progression:
## Character 1 -> always unlocked
## Character 2 -> unlocks when Character 1 reaches 40/40
## Character 3 -> unlocks when Character 2 reaches 40/40
## Character 4 -> unlocks when Character 3 reaches 40/40
## etc.

signal skin_equipped(skin_id)

const FADE_TIME := 0.15
const GREY := Color(0.55, 0.55, 0.55, 1.0)

@export var _carousel: SkinCarousel
@export var _select_button: BaseButton
@export var _prev_button: BaseButton
@export var _next_button: BaseButton
@export var _back_button: BaseButton

@export var background: TextureRect
@export var _blur_bg_list: Array[Texture]

var _skins: PlayerSkins
var _player_progress: PlayerProgress

var _index: int = 0
var _fade: Tween


# ============================================================
# SERVICE INJECTION
# ============================================================

func inject_services(registry: Node) -> void:

	super.inject_services(registry)

	_player_progress = (
		registry.get_service(
			&"player_progress"
		) as PlayerProgress
	)

	if _player_progress == null:
		push_error(
			"SkinsScene: PlayerProgress service not found."
		)
	else:
		print(
			"SkinsScene: PlayerProgress injected."
		)


# ============================================================
# READY
# ============================================================

func _on_ready() -> void:

	_skins = PlayerSkins.new(
		_save
	)

	_index = SkinCatalog.index_of(
		_skins.equipped_id()
	)

	if _carousel == null:
		push_error(
			"SkinsScene: Carousel is NULL."
		)
		return

	if _carousel.prefabs.size() != SkinCatalog.count():

		push_warning(
			"Skins: carousel has %d prefabs but SkinCatalog has %d skins."
			% [
				_carousel.prefabs.size(),
				SkinCatalog.count()
			]
		)

	_carousel.build(
		_index
	)

	# --------------------------------------------------------
	# SET INITIAL LOCK STATES
	# --------------------------------------------------------

	_refresh_all_locks()

	# --------------------------------------------------------
	# GAME BUS
	# --------------------------------------------------------

	if _bus:

		if not _bus.character_changed.is_connected(
			_on_character_changed
		):

			_bus.character_changed.connect(
				_on_character_changed
			)

	# --------------------------------------------------------
	# CAROUSEL SIGNALS
	# --------------------------------------------------------

	_carousel.selected.connect(
		_on_selected
	)

	_carousel.moving.connect(
		_on_moving
	)

	_carousel.settled.connect(
		_on_settled
	)

	# --------------------------------------------------------
	# BUTTONS
	# --------------------------------------------------------

	_on_press(
		_prev_button,
		_carousel.previous
	)

	_on_press(
		_next_button,
		_carousel.next
	)

	_on_press(
		_select_button,
		_on_select_pressed
	)

	_on_press(
		_back_button,
		close
	)

	_update_arrows()
	_refresh_select_button(false)

	_Setup_Bg_at_first_world()


# ============================================================
# REFRESH ALL LOCKS
# ============================================================

func _refresh_all_locks() -> void:

	if _player_progress == null:
		return

	for i in SkinCatalog.count():

		var skin_data: Dictionary = SkinCatalog.at(i)

		var skin_id: String = str(
			skin_data.get("id", "")
		)

		var unlocked: bool = (
			_player_progress.is_character_unlocked(
				skin_id
			)
		)

		_carousel.set_locked(
			i,
			not unlocked
		)


# ============================================================
# CHARACTER CHANGED
# ============================================================

func _on_character_changed(
	character_id: String
) -> void:

	print(
		"========== SKINS REFRESH =========="
	)

	print(
		"SkinsScene: Character changed = ",
		character_id
	)

	# Re-read equipped/owned skin data.
	_skins = PlayerSkins.new(
		_save
	)

	# Recalculate every character's lock state.
	_refresh_all_locks()

	# Update Select button for the currently displayed character.
	_refresh_select_button(true)

	print(
		"SkinsScene: Character locks refreshed."
	)

	print(
		"===================================="
	)


# ============================================================
# BACKGROUND
# ============================================================

func _Setup_Bg_at_first_world() -> void:

	var world_index: int = 0

	var current_level: int = (
		_save.get_level()
	)

	if current_level <= 10:
		world_index = 0

	elif current_level <= 20:
		world_index = 1

	elif current_level <= 30:
		world_index = 2

	elif current_level <= 40:
		world_index = 3

	elif current_level <= 50:
		world_index = 4

	else:
		world_index = 0

	select_bg_for_world(
		world_index
	)


func select_bg_for_world(
	index: int
) -> void:

	if index < _blur_bg_list.size():

		background.texture = (
			_blur_bg_list[index]
		)

	else:

		background.texture = null

		_logger.warn(
			"SkinsScene: no blur background for world index ",
			index
		)


# ============================================================
# CAROUSEL
# ============================================================

func _on_selected(
	index: int
) -> void:

	_index = index

	_update_arrows()


func _on_moving() -> void:

	# Can't select while carousel is moving.
	_select_button.disabled = true

	_fade_button_to(
		Color(1, 1, 1, 0)
	)


func _on_settled(
	_index_settled: int
) -> void:

	_refresh_select_button(
		true
	)


# ============================================================
# SELECT CHARACTER
# ============================================================

func _on_select_pressed() -> void:

	var skin: Dictionary = (
		SkinCatalog.at(_index)
	)

	var skin_id: String = str(
		skin.get("id", "")
	)

	if not _can_select(
		skin_id
	):
		return

	_skins.equip(
		skin_id
	)

	_carousel.bounce_at(
		_index
	)

	skin_equipped.emit(
		skin_id
	)

	# Equipped character is now grey / "Equipped".
	_refresh_select_button(
		true
	)


# ============================================================
# CAN SELECT
# ============================================================

func _can_select(
	skin_id: String
) -> bool:

	if _player_progress == null:
		return false

	if _skins == null:
		return false

	# Must be unlocked through character progression.
	if not _player_progress.is_character_unlocked(
		skin_id
	):
		return false

	# Already equipped.
	if _skins.equipped_id() == skin_id:
		return false

	return true


# ============================================================
# SELECT BUTTON
# ============================================================

func _refresh_select_button(
	animate: bool
) -> void:

	if _select_button == null:
		return

	if _index < 0 or _index >= SkinCatalog.count():
		return

	var skin: Dictionary = (
		SkinCatalog.at(_index)
	)

	var skin_id: String = str(
		skin.get("id", "")
	)

	var can_select: bool = (
		_can_select(
			skin_id
		)
	)

	_select_button.disabled = not can_select

	var target: Color = (
		Color.WHITE
		if can_select
		else GREY
	)

	if animate:

		_fade_button_to(
			target
		)

	else:

		if _fade:
			_fade.kill()

		_select_button.modulate = target


func _fade_button_to(
	target: Color
) -> void:

	if _fade:
		_fade.kill()

	_fade = create_tween()

	_fade.tween_property(
		_select_button,
		"modulate",
		target,
		FADE_TIME
	)


# ============================================================
# ARROWS
# ============================================================

func _update_arrows() -> void:

	if _prev_button == null:
		return

	if _next_button == null:
		return

	var at_start: bool = (
		_index <= 0
	)

	var at_end: bool = (
		_index >= SkinCatalog.count() - 1
	)

	_prev_button.disabled = at_start
	_next_button.disabled = at_end

	_prev_button.modulate.a = (
		0.35
		if at_start
		else 1.0
	)

	_next_button.modulate.a = (
		0.35
		if at_end
		else 1.0
	)
