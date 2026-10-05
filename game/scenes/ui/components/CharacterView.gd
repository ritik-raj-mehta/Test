class_name CharacterView
extends Control

## CharacterView — the DEFAULT character prefab (used when a skin has no "scene").
## Put your character art in %Body (or give a skin a "texture" key in SkinCatalog).
## %LockIcon shows for locked skins.
## Custom character prefabs don't need this script; see SkinCarousel.gd for the
## optional set_locked() / bounce() methods they can implement.

const LOCKED_TINT: Color = Color("#000000c0")

@export var _body: TextureRect #= %Body
@export var _lock: Control #= %LockIcon

func set_skin(skin: Dictionary, locked: bool = false) -> void:
	if _body == null:
		push_error("CharacterView: Body TextureRect is not assigned.")
		return

	var art = skin.get("texture", "")

	if art is Texture2D:
		_body.texture = art

	elif art is String and not art.is_empty():
		if ResourceLoader.exists(art):
			var texture := load(art) as Texture2D

			if texture:
				_body.texture = texture
			else:
				push_error(
					"CharacterView: Failed to load texture: "
					+ art
				)
		else:
			push_error(
				"CharacterView: Texture does not exist: "
				+ art
			)

	else:
		push_error(
			"CharacterView: Invalid texture for skin: "
			+ str(skin.get("id", "unknown"))
		)

	set_locked(locked)

func set_locked(locked: bool) -> void:
	# _body.self_modulate = LOCKED_TINT if locked else Color.WHITE
	_lock.visible = locked

func bounce() -> void:
	UIAnim.bounce(self)
