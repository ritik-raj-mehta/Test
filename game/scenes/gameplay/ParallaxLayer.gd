class_name ParallaxLayerNew
extends Sprite2D

@export var parallax_factor: float = 0.5

## Unique key used by ParallaxTheme to pick this layer's texture and position.
@export var layer_key: StringName = &""

## Where this layer sits when a level starts (scene position, or the ParallaxTheme position).
var base_position: Vector2
## Parallax offsets are measured from this Y. Equals base_position.y at level start;
## re-pinned to the current spot after a death so nothing snaps on the next unlock.
var anchor_y: float

var _base_set: bool = false


func _ready() -> void:
	if not _base_set:  # a theme may already have set the position before _ready
		base_position = position
		anchor_y = position.y
		_base_set = true


func set_layer_texture(tex: Texture2D) -> void:
	if tex and texture != tex:
		texture = tex


## Sets the START position (theme data). Parallax is measured from here.
func set_layer_position(pos: Vector2) -> void:
	position = pos
	base_position = pos
	anchor_y = pos.y
	_base_set = true


## New level / retry: back to the start look.
func reset_to_base() -> void:
	position = base_position
	anchor_y = base_position.y


## Freeze the current spot as the new origin (used when the player dies).
func pin_here() -> void:
	anchor_y = position.y
