class_name SkinsScene
extends AppView

## SkinsScene — swipe/drag or use the arrows to browse skins, press Select to equip.
## Select button: fades out while the carousel moves, fades back in when it settles.
## Active (white) only for an owned, not-yet-equipped skin; grey + untappable otherwise.
## Layout: Skins.tscn

## Emitted after the player equips a skin.
signal skin_equipped(skin_id)
## Emit this (e.g. forwarded from the game bus) after a skin becomes owned;
## the scene refreshes the preview and the button.
##   GameBus.skin_unlocked.connect(skins_scene.skin_unlocked.emit)
signal skin_unlocked(skin_id)

const FADE_TIME := 0.15
const GREY := Color(0.55, 0.55, 0.55, 1.0)

@export var _carousel: SkinCarousel #= %Carousel
@export var _select_button: BaseButton #= %SelectButton
@export var _prev_button: BaseButton #= %PrevButton
@export var _next_button: BaseButton #= %NextButton
@export var _back_button: BaseButton #= %BackButton

var _skins: PlayerSkins
var _index: int = 0
var _fade: Tween

func _on_ready() -> void:
	_skins = PlayerSkins.new(_save)
	_index = SkinCatalog.index_of(_skins.equipped_id())

	if _carousel.prefabs.size() != SkinCatalog.count():
		push_warning("Skins: carousel has %d prefabs but SkinCatalog has %d skins." \
			% [_carousel.prefabs.size(), SkinCatalog.count()])
	_carousel.build(_index)
	for i in SkinCatalog.count():
		_carousel.set_locked(i, not _skins.is_owned(SkinCatalog.at(i)["id"]))
	_carousel.selected.connect(_on_selected)
	_carousel.moving.connect(_on_moving)
	_carousel.settled.connect(_on_settled)
	skin_unlocked.connect(_on_skin_unlocked)

	_on_press(_prev_button, _carousel.previous)
	_on_press(_next_button, _carousel.next)
	_on_press(_select_button, _on_select_pressed)
	_on_press(_back_button, close)
	_update_arrows()
	_refresh_select_button(false)

func _on_selected(index: int) -> void:
	_index = index
	_update_arrows()

func _on_moving() -> void:
	_select_button.disabled = true  # can't tap mid-swipe
	_fade_button_to(Color(1, 1, 1, 0))

func _on_settled(_index_settled: int) -> void:
	_refresh_select_button(true)

func _on_select_pressed() -> void:
	var skin := SkinCatalog.at(_index)
	if not _can_select(skin["id"]):
		return
	_skins.equip(skin["id"])
	_carousel.bounce_at(_index)
	skin_equipped.emit(skin["id"])
	_refresh_select_button(true)  # now "Equipped" → goes grey

func _on_skin_unlocked(skin_id) -> void:
	_skins = PlayerSkins.new(_save)  # re-read ownership
	var i := SkinCatalog.index_of(skin_id)
	_carousel.set_locked(i, not _skins.is_owned(skin_id))
	_refresh_select_button(true)

func _can_select(skin_id) -> bool:
	return _skins.is_owned(skin_id) and _skins.equipped_id() != skin_id

func _refresh_select_button(animate: bool) -> void:
	var can_select := _can_select(SkinCatalog.at(_index)["id"])
	_select_button.disabled = not can_select
	var target := Color.WHITE if can_select else GREY
	if animate:
		_fade_button_to(target)
	else:
		if _fade:
			_fade.kill()
		_select_button.modulate = target

func _fade_button_to(target: Color) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_select_button, "modulate", target, FADE_TIME)

func _update_arrows() -> void:
	var at_start := _index <= 0
	var at_end := _index >= SkinCatalog.count() - 1
	_prev_button.disabled = at_start
	_next_button.disabled = at_end
	_prev_button.modulate.a = 0.35 if at_start else 1.0
	_next_button.modulate.a = 0.35 if at_end else 1.0
