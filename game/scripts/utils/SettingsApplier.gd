class_name SettingsApplier
extends RefCounted

## SettingsApplier — pushes saved SettingsData into AudioManager / HapticsManager.
## Called once on Loading and again whenever the Settings popup changes a value.

const MUTED_LINEAR: float = 0.0001  # ≈ -80 dB, avoids linear_to_db(0) = -inf

static func apply(settings: GameModels.SettingsData, audio: AudioManager, haptics: HapticsManager) -> void:
	if settings == null:
		return
	if audio:
		audio.set_music_volume(settings.music_volume if settings.music_enabled else MUTED_LINEAR)
		audio.set_sfx_volume(settings.sfx_volume if settings.sfx_enabled else MUTED_LINEAR)
	if haptics:
		haptics.set_enabled(settings.haptics_enabled)
