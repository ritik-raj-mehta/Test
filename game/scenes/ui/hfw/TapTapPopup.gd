class_name TapTapPopup
extends CharacterPopup

signal progress_changed(value: float)

@export var character_id: String = ""
@export var rays_speed: float = 0.12
@export var fruit_y_offset: float = 70.0
@export var tilt_angle: float = 7.5
@export var fruit_y_offsets: Dictionary = {
	"zumpa_green": 70.0,
	"sunny": 150.0,
	"berry": 150.0,
	"skyblue": 70.0,
	"grape": 70.0,
}
var _equipped_skin_id: String = ""

# Eating tilt & bite animation state
var _eat_tilt_right: bool = false
var _character_tween: Tween = null
var _fruit_tween: Tween = null

@onready var _rays: Control = %Rays
@onready var _tap_area: Control = %TapArea
@onready var _character: CharacterView = %Character
@onready var _progress_bar: SkinProgress = %Progress
@onready var _ring_progress: RingProgress = %CountDownProgress

@onready var _unlock_panel: Control = %UnlockPanel
@onready var _unlock_content: Control = %UnlockContent
@onready var _unlock_character: CharacterView = %UnlockChar
@onready var _equip_button: BaseButton = %Equip
@onready var _continue_button: BaseButton = %Continue
@onready var _taptap_content: Control = $TapTapContent
@onready var _countdown_panel: Control = %CountDownProgress

# Fruit eating sprite (created dynamically in the Middle container)
var _fruit_sprite: TextureRect = null

var _current_progress: int = 0
var _progress_before: float = 0.0
var _progress_after: float = 0.0
var _character_completed: bool = false
var _completion_sent: bool = false

# Unlock state
var _player_skins: PlayerSkins
var _unlock_character_id: String = ""
var _unlock_panel_open: bool = false

# ============================================================
# EATING STATE  (always active)
# ============================================================

var _eating_tap_count: int = 0

# ApplePhases.png has 6 horizontal frames:
# Frame 0 = full apple (no bite)
# Frame 1–5 = progressive bites (5 eating phases)
const FRUIT_TOTAL_FRAMES: int = 6
const FRUIT_EATING_PHASES: int = 5

# replace TAPS_PER_PHASE
const TAPS_PER_CYCLE: int = 20
# Cached textures for eating/tap/release character faces
var _first_texture: Texture2D = null
var _tap_texture: Texture2D = null
var _release_texture: Texture2D = null
var _equipped_skin_data: Dictionary = {}

# True when all characters have been unlocked → hide progress bar
var _no_more_unlocks: bool = false


func inject_services(registry: Node) -> void:
	super.inject_services(registry)

	_player_skins = PlayerSkins.new(_save)

	if _bus and not _bus.character_changed.is_connected(_on_character_changed):
		_bus.character_changed.connect(_on_character_changed)


func _on_ready() -> void:
	# Connect unlock buttons
	_on_press(_equip_button, _on_unlock_equip)
	_on_press(_continue_button, _on_unlock_continue)

	# Hidden until a new character is unlocked
	if _unlock_panel:
		_unlock_panel.visible = false

	call_deferred("_initialize_popup")


func _process(delta: float) -> void:
	if _rays:
		_rays.rotation += rays_speed * delta


# ============================================================
# PROGRESS HELPERS
# ============================================================

func _progress_ratio() -> float:
	return clampf(
		float(_current_progress) / float(CharacterProgress.REQUIRED_TAPS),
		0.0, 1.0
	)


# Reads saved progress and snaps the bar to it (no animation from 0).
func _load_progress() -> void:
	_current_progress = _player_progress.get_current_progress() if _player_progress else 0

	var progress := _progress_ratio()

	_progress_before = progress
	_progress_after = progress

	if _progress_bar:
		_progress_bar.set_value_instant(progress)


# ============================================================
# INIT / OPEN
# ============================================================

func _initialize_popup() -> void:
	_character_completed = false
	_completion_sent = false

	_unlock_character_id = ""
	_unlock_panel_open = false
	_eating_tap_count = 0

	if _unlock_panel:
		_unlock_panel.visible = false
		
	if _taptap_content:
		_taptap_content.visible = true

	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is not available.")
	else:
		character_id = _player_progress.get_current_character_id()

		# Check if all characters are already unlocked
		_no_more_unlocks = _player_progress.is_all_characters_completed()

		if _no_more_unlocks:
			# No character to unlock — hide progress bar
			if _progress_bar:
				_progress_bar.visible = false
		else:
			# Progress/badge = progression character
			if _progress_bar:
				_progress_bar.visible = true
			_apply_next_badge(_progress_bar)
			_load_progress()

	# ── EATING SETUP (always) ──
	_setup_eating()

	# ── TAP INPUT (always uses press + release) ──
	if _tap_area:
		_bind_tap_and_release(_tap_area)
	else:
		push_error("TapTapPopup: _tap_area is not assigned.")

	if _ring_progress:
		if not _ring_progress.countdown_finished.is_connected(_on_countdown_finished):
			_ring_progress.countdown_finished.connect(_on_countdown_finished)

		_ring_progress.start_countdown()
	else:
		push_error("TapTapPopup: RingProgress is not assigned.")


func prepare_for_open() -> void:
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return

	_character_completed = false
	_completion_sent = false

	_unlock_character_id = ""
	_unlock_panel_open = false
	_eating_tap_count = 0

	if _unlock_panel:
		_unlock_panel.visible = false
	if _taptap_content:
		_taptap_content.visible = true
	character_id = _player_progress.get_current_character_id()

	# Check if all characters are already unlocked
	_no_more_unlocks = _player_progress.is_all_characters_completed()

	if _no_more_unlocks:
		if _progress_bar:
			_progress_bar.visible = false
	else:
		if _progress_bar:
			_progress_bar.visible = true
		_apply_next_badge(_progress_bar)
		_load_progress()

	# ── EATING SETUP (always) ──
	_setup_eating()


# Kept in case something outside still calls it.
func initialize_progress() -> void:
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return

	character_id = _player_progress.get_current_character_id()

	_load_progress()


# ============================================================
# EATING SETUP  (runs every time the popup opens)
# ============================================================

func _get_fruit_y_offset(skin_id: String) -> float:
	if fruit_y_offsets.has(skin_id):
		return float(fruit_y_offsets[skin_id])

	# Fallback: check alias like "char1", "char2", etc.
	var idx := SkinCatalog.index_of(skin_id) + 1
	var alias := "char" + str(idx)
	if fruit_y_offsets.has(alias):
		return float(fruit_y_offsets[alias])

	return fruit_y_offset


func _setup_eating() -> void:
	# Reset tap count so the fruit starts fresh (full)
	_eating_tap_count = 0

	# Cache the equipped skin ID for tap/release textures
	var equipped_id: String = PlayerSkins.resolve_equipped(
		_save,
		_player_progress
	)
	_equipped_skin_id = equipped_id
	_equipped_skin_data = SkinCatalog.get_skin(equipped_id)

	# Load eating frames (char1Eating.png has 3 frames: Frame 0 = 1st image on open, Frame 1 = 2nd image on tap, Frame 2 = 3rd image on release)
	var eating_frames := SkinCatalog.get_eating_frames(equipped_id)

	if eating_frames.size() >= 3:
		_first_texture = eating_frames[0]
		_tap_texture = eating_frames[1]
		_release_texture = eating_frames[2]
	elif eating_frames.size() == 2:
		_first_texture = eating_frames[0]
		_tap_texture = eating_frames[1]
		_release_texture = SkinCatalog.get_release_texture(equipped_id)
	elif eating_frames.size() == 1:
		_first_texture = eating_frames[0]
		_tap_texture = SkinCatalog.get_tap_texture(equipped_id)
		_release_texture = SkinCatalog.get_release_texture(equipped_id)
	else:
		_first_texture = SkinCatalog.get_release_texture(equipped_id)
		_tap_texture = SkinCatalog.get_tap_texture(equipped_id)
		_release_texture = SkinCatalog.get_release_texture(equipped_id)

	# Reset character transform
	if _character:
		_character.rotation_degrees = 0.0
		_character.scale = Vector2.ONE

	# 1st image when panel opens: Frame 0 of char1Eating.png (_first_texture)
	if _character and _first_texture:
		_character.set_texture_direct(_first_texture)
	elif _character and _release_texture:
		_character.set_texture_direct(_release_texture)
	elif _character:
		_character.set_skin(_equipped_skin_data)

	# Create (or recreate) the fruit sprite — always starts at phase 0
	_create_fruit_sprite()
	_update_fruit_phase(0)


func _create_fruit_sprite() -> void:
	# Get the fruit eat texture from the current world theme
	var theme_id: String = WorldThemeRegistry.get_current_theme()
	var fruit_tex: Texture2D = WorldThemeRegistry.get_fruit_eat_texture(theme_id)

	if fruit_tex == null:
		push_error("TapTapPopup: Fruit eat texture not found for theme: " + theme_id)
		return

	# Find the Middle container where the character sits
	var middle: Control = _taptap_content.get_node_or_null("Column/Middle")
	if middle == null:
		push_error("TapTapPopup: Middle container not found.")
		return

	# Remove old fruit sprite / wrapper if it exists
	if _fruit_sprite and is_instance_valid(_fruit_sprite):
		var old_parent = _fruit_sprite.get_parent()
		if old_parent and is_instance_valid(old_parent) and old_parent != middle:
			old_parent.queue_free()
		else:
			_fruit_sprite.queue_free()
		_fruit_sprite = null

	# Wrapper container placed in Middle CenterContainer
	var wrapper := Control.new()
	wrapper.name = "FruitWrapper"
	wrapper.custom_minimum_size = Vector2(200, 200)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Resolve y_offset for current equipped character
	var y_off := _get_fruit_y_offset(_equipped_skin_id)

	# Create the fruit TextureRect using AtlasTexture for frame display
	_fruit_sprite = TextureRect.new()
	_fruit_sprite.name = "FruitEat"
	_fruit_sprite.custom_minimum_size = Vector2(200, 200)
	_fruit_sprite.size = Vector2(200, 200)
	_fruit_sprite.position = Vector2(0, y_off) # Shifts fruit per-character
	_fruit_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fruit_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fruit_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create an AtlasTexture for the first frame
	var atlas := AtlasTexture.new()
	atlas.atlas = fruit_tex
	var frame_width: float = fruit_tex.get_width() / float(FRUIT_TOTAL_FRAMES)
	var frame_height: float = fruit_tex.get_height()
	atlas.region = Rect2(0, 0, frame_width, frame_height)
	_fruit_sprite.texture = atlas

	wrapper.add_child(_fruit_sprite)
	middle.add_child(wrapper)


func _update_fruit_phase(phase_index: int) -> void:
	if _fruit_sprite == null or not is_instance_valid(_fruit_sprite):
		return

	var atlas: AtlasTexture = _fruit_sprite.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return

	# Clamp phase_index to valid range (0 to FRUIT_TOTAL_FRAMES - 1)
	phase_index = clampi(phase_index, 0, FRUIT_TOTAL_FRAMES - 1)

	var frame_width: float = atlas.atlas.get_width() / float(FRUIT_TOTAL_FRAMES)
	var frame_height: float = atlas.atlas.get_height()

	atlas.region = Rect2(
		phase_index * frame_width,
		0,
		frame_width,
		frame_height
	)


## Returns the current fruit phase (0–5).
## When the fruit is fully eaten (phase 5) the next tap resets it to 0.
func _fruit_phase_from_taps() -> int:
	if _eating_tap_count <= 0:
		return 0
	# Phase cycles: every TAPS_PER_PHASE * FRUIT_EATING_PHASES taps the
	# fruit resets to full.  Within one cycle each TAPS_PER_PHASE taps
	# advances one phase.
	var pos: int = _eating_tap_count % (TAPS_PER_CYCLE + 1)
	if pos == 0:
		return 0
	return clampi(
		int(ceil(float(pos * FRUIT_EATING_PHASES) / float(TAPS_PER_CYCLE))),
		1,
		FRUIT_EATING_PHASES
	)


# ============================================================
# TAP / RELEASE INPUT  (always active)
# ============================================================

func _bind_tap_and_release(area: Control) -> void:
	area.gui_input.connect(_on_tap_input)


func _on_tap_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_on_tap_press()
		else:
			_on_tap_release()

	elif e is InputEventScreenTouch:
		if e.pressed:
			_on_tap_press()
		else:
			_on_tap_release()


func _animate_eat_press() -> void:
	if _character == null:
		return

	# Alternate head tilt angle left (-tilt_angle) and right (+tilt_angle)
	_eat_tilt_right = not _eat_tilt_right
	var target_tilt: float = tilt_angle if _eat_tilt_right else -tilt_angle

	if _character.size.x > 0 and _character.size.y > 0:
		_character.pivot_offset = _character.size / 2.0
	else:
		_character.pivot_offset = Vector2(100, 100)

	if _character_tween and _character_tween.is_running():
		_character_tween.kill()

	_character_tween = create_tween().set_parallel(true)
	_character_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Head tilt and bite squash scale impulse
	_character_tween.tween_property(_character, "rotation_degrees", target_tilt, 0.07)
	_character_tween.tween_property(_character, "scale", Vector2(1.12, 0.9), 0.06)

	# Fruit bite punch pulse
	if _fruit_sprite and is_instance_valid(_fruit_sprite):
		_fruit_sprite.pivot_offset = Vector2(100, 100)
		if _fruit_tween and _fruit_tween.is_running():
			_fruit_tween.kill()

		_fruit_tween = create_tween()
		_fruit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fruit_tween.tween_property(_fruit_sprite, "scale", Vector2(0.85, 0.85), 0.05)
		_fruit_tween.tween_property(_fruit_sprite, "scale", Vector2.ONE, 0.1)


func _animate_eat_release() -> void:
	if _character == null:
		return

	if _character_tween and _character_tween.is_running():
		_character_tween.kill()

	_character_tween = create_tween().set_parallel(true)
	_character_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Return rotation back upright (0.0°) and restore normal scale (1.0, 1.0)
	_character_tween.tween_property(_character, "rotation_degrees", 0.0, 0.12)
	_character_tween.tween_property(_character, "scale", Vector2.ONE, 0.12)


func _on_tap_press() -> void:
	if _character_completed:
		return

	# ── CHARACTER FACE: open mouth ──
	if _character and _tap_texture:
		_character.set_texture_direct(_tap_texture)

	# ── REALISTIC EATING ANIMATION: Head tilt + bite squash + fruit pulse ──
	_animate_eat_press()

	if _haptics:
		_haptics.light()

	# ── FRUIT EATING (always) ──
	_eating_tap_count += 1
	var phase := _fruit_phase_from_taps()
	_update_fruit_phase(phase)

	# ── CHARACTER PROGRESSION (only when there are characters to unlock) ──
	if not _no_more_unlocks:
		_advance_character_progress()


func _on_tap_release() -> void:
	# ── CHARACTER FACE: closed mouth ──
	if _character and _release_texture:
		_character.set_texture_direct(_release_texture)

	# ── RELEASE ANIMATION: Tilt back upright ──
	_animate_eat_release()


# ============================================================
# CHARACTER PROGRESSION  (only when _no_more_unlocks == false)
# ============================================================

func _advance_character_progress() -> void:
	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return

	if character_id.is_empty():
		push_error("TapTapPopup: character_id is empty.")
		return

	_current_progress = _player_progress.add_progress(1)

	var progress := _progress_ratio()

	_progress_after = progress

	if _save:
		var result := _save.save_game()

		if result != null and not result.success:
			push_error(
				"Failed to save character progress: "
				+ result.error_message
			)

	if _progress_bar:
		_progress_bar.animate_to(
			_progress_bar.get_value(),
			progress,
			0.15
		)

	progress_changed.emit(progress)

	# ========================================================
	# CHARACTER COMPLETED
	# ========================================================

	if _current_progress >= CharacterProgress.REQUIRED_TAPS:
		_character_completed = true

		# The current character just filled its own bar — it is the one
		# being unlocked. Always show the unlock panel.
		_show_unlock_panel()


# ============================================================
# EVENTS
# ============================================================

func _on_character_changed(new_character_id: String) -> void:
	# Ignore signal if unlock panel is currently open (equipping from unlock panel)
	# to prevent premature UI reset / flicker before completion.
	if _unlock_panel_open:
		return

	_character_completed = false
	_completion_sent = false

	_unlock_character_id = ""
	_unlock_panel_open = false

	if _unlock_panel:
		_unlock_panel.visible = false

	character_id = new_character_id

	# Re-check unlock status
	_no_more_unlocks = (
		_player_progress.is_all_characters_completed()
		if _player_progress else false
	)

	if _no_more_unlocks:
		if _progress_bar:
			_progress_bar.visible = false
	else:
		if _progress_bar:
			_progress_bar.visible = true
		_apply_next_badge(_progress_bar)
		_load_progress()

	# Re-setup eating (reset fruit, reload textures)
	_setup_eating()

	progress_changed.emit(_progress_ratio())


func _on_countdown_finished() -> void:
	# Countdown still completes the level when the character
	# has not reached 100%.
	if _character_completed:
		return

	_finish_tap_tap()


# ============================================================
# SHOW UNLOCK PANEL
# ============================================================

func _show_unlock_panel() -> void:
	if _unlock_panel_open:
		return

	# The character being unlocked is the one that just completed its
	# own 40-tap progression — i.e. current_character_id itself.
	_unlock_character_id = _player_progress.get_current_character_id() \
		if _player_progress else ""

	if _unlock_character_id.is_empty():
		_finish_tap_tap()
		return

	if _player_skins == null:
		push_error("TapTapPopup: PlayerSkins is null.")
		return

	var unlocked := _player_skins.unlock(_unlock_character_id)

	if not unlocked:
		push_error(
			"TapTapPopup: Failed to unlock "
			+ _unlock_character_id
		)
		_finish_tap_tap()
		return

	# --------------------------------------------------------
	# PAUSE COUNTDOWN WHILE UNLOCK PANEL IS OPEN
	# --------------------------------------------------------

	if _ring_progress:
		_ring_progress.pause_countdown()

	# --------------------------------------------------------
	# SHOW NEW CHARACTER
	# --------------------------------------------------------

	var skin_data: Dictionary = SkinCatalog.get_skin(
		_unlock_character_id
	)

	if _unlock_character:
		_unlock_character.set_skin(skin_data)
	
	_unlock_panel_open = true
	if _taptap_content:
		_taptap_content.visible = false

	if _countdown_panel:
		_countdown_panel.visible = false
		
	if _unlock_panel:
		_unlock_panel.visible = true

	if _unlock_content:
		_unlock_content.scale = Vector2.ZERO

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)

		tween.tween_property(
			_unlock_content,
			"scale",
			Vector2.ONE,
			0.45
		)


# ============================================================
# EQUIP
# ============================================================

func _on_unlock_equip() -> void:
	if _unlock_character_id.is_empty():
		return

	if _player_skins == null:
		push_error("TapTapPopup: PlayerSkins is null.")
		return

	var success := _player_skins.equip(
		_unlock_character_id
	)

	if not success:
		push_error(
			"TapTapPopup: Failed to equip "
			+ _unlock_character_id
		)
		return

	print(
		"TapTapPopup: Equipped new character = ",
		_unlock_character_id
	)

	if _bus:
		_bus.character_changed.emit(
			_unlock_character_id
		)

	_finish_unlock_choice()


# ============================================================
# CONTINUE
# ============================================================

func _on_unlock_continue() -> void:
	print(
		"TapTapPopup: Continue with existing equipped character."
	)

	# The new character is already owned.
	# We intentionally do NOT equip it.

	_finish_unlock_choice()


# ============================================================
# FINISH UNLOCK CHOICE
# ============================================================

func _finish_unlock_choice() -> void:
	if _unlock_character_id.is_empty():
		push_error("TapTapPopup: Unlock character ID is empty.")
		return

	if _player_progress == null:
		push_error("TapTapPopup: PlayerProgress is null.")
		return

	# Save the character we just unlocked.
	var unlocked_character_id: String = _unlock_character_id

	# Move progression to the NEXT character after the
	# newly unlocked one.
	var next_progression_id: String = (
		_player_progress.activate_next_locked_character_after(
			unlocked_character_id
		)
	)

	print(
		"TapTapPopup: Next progression character = ",
		next_progression_id
	)

	_unlock_panel_open = false
	_unlock_character_id = ""

	_finish_tap_tap()


# ============================================================
# FINISH TAP-TAP
# ============================================================

func _finish_tap_tap() -> void:
	if _completion_sent:
		return

	_completion_sent = true

	# Clean up fruit sprite wrapper
	if _fruit_sprite and is_instance_valid(_fruit_sprite):
		var parent = _fruit_sprite.get_parent()
		var middle = _taptap_content.get_node_or_null("Column/Middle") if _taptap_content else null
		if parent and is_instance_valid(parent) and parent != middle:
			parent.queue_free()
		else:
			_fruit_sprite.queue_free()
		_fruit_sprite = null

	print(
		"TapTapPopup: TapTap completion confirmed."
	)

	if _bus:
		_bus.tap_tap_completed.emit(
			_progress_before,
			_progress_after
		)
	else:
		push_error(
			"TapTapPopup: GameBus is NULL."
	)
