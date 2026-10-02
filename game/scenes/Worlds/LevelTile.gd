class_name LevelTile
extends TextureButton

## LevelTile — one number button in the Worlds level grid (see worlds_Reff.png).
## Scene: LevelTile.tscn. Instanced and arranged by LevelGrid.gd.
##
## States:
##   LOCKED    - not reachable yet: dimmed/lock art, taps shake instead of opening.
##   CURRENT   - the level the player would resume (highlighted / accent colour).
##   COMPLETED - already cleared at least once (its own art + stars).
##   OPEN      - unlocked but not yet played (default art, no stars).
## Swap the four state textures in the inspector (or in the scene) with your art.

enum State { LOCKED, CURRENT, COMPLETED, OPEN }

signal chosen(level: int)

const POP_TIME := 0.28
const POP_OVERSHOOT := 1.15

@export var locked_texture: Texture2D
@export var current_texture: Texture2D
@export var completed_texture: Texture2D
@export var open_texture: Texture2D

@export var _number: Label #= %Number
@export var _lock: Control #= %Lock
@export var _stars: Control #= %Stars

var level: int = 0
var state: State = State.OPEN

func _ready() -> void:
	pressed.connect(_on_pressed)
	pivot_offset = size * 0.5

func setup(p_level: int, p_state: State, earned_stars: int = 0) -> void:
	level = p_level
	state = p_state
	_number.text = str(level)
	# _number.visible = state != State.LOCKED
	_lock.visible = state == State.LOCKED
	match state:
		State.LOCKED:    texture_normal = locked_texture
		State.CURRENT:   texture_normal = current_texture
		State.COMPLETED: texture_normal = completed_texture
		_:               texture_normal = open_texture
	texture_pressed = texture_normal
	_stars.visible = state == State.COMPLETED and earned_stars > 0
	for i in _stars.get_child_count():
		var star := _stars.get_child(i) as CanvasItem
		star.modulate = Color.WHITE if i < earned_stars else Color(1, 1, 1, 0.35)

## Scale pop-in entrance, used when the tile's world becomes the active carousel page.
## `delay` staggers tiles across the grid so they don't all pop at once.
func pop_in(delay: float = 0.0) -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ZERO
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2.ONE * POP_OVERSHOOT, POP_TIME * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_TIME * 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var fade := create_tween()
	fade.tween_interval(delay)
	fade.tween_property(self, "modulate:a", 1.0, POP_TIME * 0.5)

func _on_pressed() -> void:
	if state == State.LOCKED:
		UIAnim.shake(self)
		return
	chosen.emit(level)
