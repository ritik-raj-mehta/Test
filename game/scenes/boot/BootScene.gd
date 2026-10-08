#class_name BootScene
#extends Node
#
### BootScene — Entry point bootstrap scene
### Initializes core services and transitions to Loading (which then opens Home).
#
#@export var next_scene_path: String = "res://game/scenes/loading/Loading.tscn"
#@onready var services: Node = $GameService
#
#func _ready() -> void:
	#if services and services.logger:
		#services.logger.info("Bootstrap sequence started...")
	#SoundRegistry.preload_all()
	#ObjectRegistry.preload_all()
	#LevelLoader.prewarm_prefabs()
	#if services.save and services.save.settings_data:
#<<<<<<< Updated upstream
		#SettingsApplier.apply(services.save.settings_data, services.audio, services.haptics)
	## Transition to initial game scene / Home
#=======
		#services.audio.set_music_enabled(services.save.settings_data.music_enabled)
		#services.audio.set_sfx_enabled(services.save.settings_data.sfx_enabled)
	## Transition to initial game scene / Loading
#>>>>>>> Stashed changes
	#_transition_to_game()
#
#func _transition_to_game() -> void:
	#if services and services.scene and ResourceLoader.exists(next_scene_path):
		#services.scene.go_to(next_scene_path)
	#elif services and services.logger:
		#services.logger.info("Bootstrap complete. Ready for gameplay scenes.")


class_name BootScene
extends Node

## BootScene — Entry point bootstrap scene
## Initializes core services and transitions to Loading,
## which then opens Home.

@export var next_scene_path: String = "res://game/scenes/loading/Loading.tscn"

@onready var services: Node = $GameService


func _ready() -> void:
	if services and services.logger:
		services.logger.info("Bootstrap sequence started...")

	# Preload required registries and gameplay resources.
	SoundRegistry.preload_all()
	ObjectRegistry.preload_all()
	LevelLoader.prewarm_prefabs()

	# Apply saved user settings.
	if services.save and services.save.settings_data:
		SettingsApplier.apply(
			services.save.settings_data,
			services.audio,
			services.haptics
		)

	# Transition to the initial Loading scene.
	_transition_to_game()


func _transition_to_game() -> void:
	if services and services.scene and ResourceLoader.exists(next_scene_path):
		services.scene.go_to(next_scene_path)
	elif services and services.logger:
		services.logger.info(
			"Bootstrap complete. Ready for gameplay scenes."
	)
