class_name AudioManager
extends Node

# AudioManager — music and pooled SFX playback
# PDF §4 CPU: idle SFX pool players have process_mode = DISABLED.
#   Re-enabled on play(), disabled again when playback finishes.
# PDF §6 SOLID: one job — audio. Volume/mute only. No game logic here.

var _music_player: AudioStreamPlayer
var _sfx_pool:     Array[AudioStreamPlayer] = []

var _sfx_enabled: bool = true
var _sfx_linear:  float = 1.0

var _music_enabled: bool = true
var _music_db:      float = 0.0

const _POOL_SIZE := 8
var _logger: Node

func configure(logger: Node) -> void:
	_logger = logger

func _ready() -> void:

	_setup_music_player()
	_setup_sfx_pool()

# ── Music ──────────────────────────────────────────────────────────────────

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	# Enable looping on the stream (AudioStreamMP3 / AudioStreamWAV / AudioStreamOggVorbis)
	if "loop" in stream:
		stream.set("loop", true)
	elif "loop_mode" in stream:
		stream.set("loop_mode", 1)

	_music_db = volume_db

	if not _music_enabled:
		if _music_player:
			_music_player.stream = stream
			_music_player.stop()
		return

	# Same stream already playing (e.g. across scene reloads): keep it seamless
	if _music_player and _music_player.playing and _music_player.stream == stream:
		_apply_music_volume()
		return

	if _music_player:
		_music_player.stream = stream
		_music_player.stop()
		_music_player.play(0.0)
		_apply_music_volume()

func stop_music() -> void:
	if _music_player:
		_music_player.stop()

func set_music_volume(linear: float) -> void:
	_music_db = linear_to_db(clampf(linear, 0.0, 1.0))
	_apply_music_volume()

func set_music_enabled(on: bool) -> void:
	var was_enabled := _music_enabled
	_music_enabled = on
	if not on:
		stop_music()
	elif not was_enabled and on:
		if _music_player and _music_player.stream:
			_music_player.stop()
			_music_player.play(0.0)
			_apply_music_volume()

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = _music_db if _music_enabled else -80.0

# ── SFX ───────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_enabled or _sfx_linear <= 0.0 or stream == null:
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	# ALWAYS so SFX still play while the tree is paused (exit/pause panels)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream       = stream
	player.volume_db    = volume_db + linear_to_db(_sfx_linear)
	player.pitch_scale  = pitch_scale
	player.play()

func set_sfx_volume(linear: float) -> void:
	_sfx_linear = clampf(linear, 0.0, 1.0)

func set_sfx_enabled(on: bool) -> void:
	_sfx_enabled = on
	if not on:
		for p in _sfx_pool:
			p.stop()
			p.process_mode = Node.PROCESS_MODE_DISABLED

# ── Global mute ───────────────────────────────────────────────────────────

func mute(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

# ── Setup ─────────────────────────────────────────────────────────────────

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"

	# Global BGM must continue during scene changes
	# and while gameplay is paused.
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(_music_player)
	_apply_music_volume()

func _setup_sfx_pool() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		# PDF §4: all pool players start disabled — zero CPU cost until needed
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.finished.connect(_on_sfx_finished.bind(p))
		add_child(p)
		_sfx_pool.append(p)

# ── Internals ─────────────────────────────────────────────────────────────

func _get_free_sfx_player() -> AudioStreamPlayer:
	# PDF §6 Time Complexity: O(n) scan on pool of 8 — acceptable fixed size
	for p in _sfx_pool:
		if not p.playing:
			return p
	if _logger:
		_logger.warn("AudioManager: SFX pool exhausted")
	return null

func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	# PDF §4: disable the player once done — no idle CPU ticking
	player.process_mode = Node.PROCESS_MODE_DISABLED
