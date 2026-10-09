class_name SoundRegistry
extends RefCounted

## SoundRegistry — Central common registry for all game sounds and background music.
## Holds asset references, sound identifiers, and playback helpers.

# ── Asset Paths ────────────────────────────────────────────────────────────
const BGM_GAMEPLAY_PATH := "res://game/assets/audio/music/bombinsound-cartoon-cartoon-music-version-3-537858.mp3"
const SFX_TAP_PATH := "res://game/assets/audio/sfx/vadim_makes_sound-soft-app-button-tap-sound-5-547873.mp3"
const SFX_POP_PATH := "res://game/assets/audio/sfx/professionalsfx-balloon-pop-sound-effect-504628.mp3"

# ── Sound Identifiers ──────────────────────────────────────────────────────
const SOUND_BGM := &"game_bgm"
const SOUND_JUMP := &"player_jump"
const SOUND_DEATH := &"player_death"
const SOUND_BOOSTER := &"player_booster"
const SOUND_LEVEL_COMPLETE := &"level_complete"
const SOUND_TAP_PRESS := &"tap_press"
const SOUND_EATING := &"eating"
const SOUND_CLICK := &"sound_click"

# Cached AudioStream instances
static var _streams: Dictionary = {}

static func get_stream(sound_id: StringName) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id] as AudioStream

	var path := ""
	match sound_id:
		SOUND_BGM:
			path = BGM_GAMEPLAY_PATH
		SOUND_JUMP, SOUND_TAP_PRESS, SOUND_CLICK:
			path = SFX_TAP_PATH
		SOUND_DEATH, SOUND_BOOSTER, SOUND_LEVEL_COMPLETE, SOUND_EATING:
			path = SFX_POP_PATH

	if not path.is_empty() and ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if sound_id == SOUND_BGM and stream:
			if "loop" in stream:
				stream.set("loop", true)
			elif "loop_mode" in stream:
				stream.set("loop_mode", 1)
		_streams[sound_id] = stream
		return stream
	return null

static var _audio_cache: AudioManager = null
static var _save_cache: SaveManager = null

## Helper to resolve AudioManager from ServiceRegistry
static func get_audio(node: Node = null) -> AudioManager:
	if _audio_cache and is_instance_valid(_audio_cache):
		return _audio_cache
	var tree: SceneTree = null
	if node != null and node.is_inside_tree():
		tree = node.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var registry: Node = tree.root.get_node_or_null("ServiceRegistry")
		if registry and registry.has_method("get_service"):
			var a = registry.get_service(&"audio")
			if a:
				_audio_cache = a as AudioManager
				return _audio_cache
	return null

## Centralized method to play any sound effect with fine-tuned pitch & volume
static func play_sound(node: Node, sound_id: StringName) -> void:
	var audio := get_audio(node)
	if audio == null:
		return
	if not _saved_flag(node, "sfx_enabled"):
		return
	var stream := get_stream(sound_id)
	if stream == null:
		return

	var pitch := 1.0
	var vol_db := 0.0

	match sound_id:
		SOUND_JUMP:
			pitch = randf_range(0.95, 1.15)
			vol_db = -2.0
		SOUND_CLICK:
			pitch = randf_range(0.95, 1.15)
			vol_db = -2.0
		SOUND_TAP_PRESS:
			pitch = randf_range(1.0, 1.1)
			vol_db = 0.0
		SOUND_EATING:
			pitch = randf_range(1.3, 1.6)
			vol_db = 1.0
		SOUND_BOOSTER:
			pitch = randf_range(1.4, 1.7)
			vol_db = 3.0
		SOUND_DEATH:
			pitch = 2.0
			vol_db = 4.0
		SOUND_LEVEL_COMPLETE:
			pitch = 1.25
			vol_db = 3.0

	audio.play_sfx(stream, vol_db, pitch)

## Centralized method to start background music
static func play_bgm(node: Node) -> void:
	var audio := get_audio(node)
	if audio == null:
		return
	var stream := get_stream(SOUND_BGM)
	if stream == null:
		return
	audio.set_music_enabled(_saved_flag(node, "music_enabled"))
	audio.play_music(stream, -3.0)

static func _saved_flag(node: Node, flag: String) -> bool:
	if _save_cache and is_instance_valid(_save_cache):
		if _save_cache.settings_data:
			return bool(_save_cache.settings_data.get(flag))
		return true
	var tree: SceneTree = null
	if node != null and node.is_inside_tree():
		tree = node.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var registry: Node = tree.root.get_node_or_null("ServiceRegistry")
		if registry and registry.has_method("get_service"):
			var save := registry.get_service(&"save") as SaveManager
			if save:
				_save_cache = save
				if _save_cache.settings_data:
					return bool(_save_cache.settings_data.get(flag))
	return true

static func preload_all() -> void:
	for id in [SOUND_BGM, SOUND_JUMP, SOUND_DEATH, SOUND_BOOSTER, SOUND_LEVEL_COMPLETE, SOUND_TAP_PRESS, SOUND_EATING, SOUND_CLICK]:
		get_stream(id)
