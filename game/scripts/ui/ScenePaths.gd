class_name ScenePaths
extends RefCounted

# Full scenes → SceneManager.go_to()
const LOADING:  String = "res://game/scenes/loading/Loading.tscn"
const SKINS:    String = "res://game/scenes/Skins/Skins.tscn"
const WORLDS:   String = "res://game/scenes/Worlds/Worlds.tscn"
const GAMEPLAY: String = "res://game/scenes/gameplay/GamePlay.tscn"
const LEVEL_EDITOR: String = "res://addons/zumpa_level_editor/level_editor.tscn"
const GOAL_SCENE_PATH: String = "res://game/scenes/obstacles/Goal.tscn"

# Popups → UIManager.push_packed()
const SETTINGS:        String = "res://game/scenes/ui/hfw/SettingsPopup.tscn"
const CREDITS:         String = "res://game/scenes/ui/hfw/CreditsPopup.tscn"
const TAP_TAP:         String = "res://game/scenes/ui/hfw/TapTapPopup.tscn"
const LEVEL_COMPLETED: String = "res://game/scenes/ui/hfw/LevelCompletedPopup.tscn"
const POLICY:         String = "res://game/scenes/ui/hfw/PolicyPopup.tscn"
const UPDATE:          String = "res://game/scenes/ui/hfw/UpdatePopup.tscn"
const SOCIAL:         String = "res://game/scenes/ui/hfw/SocialPopup.tscn"
const QUIT: String = "res://game/scenes/ui/hfw/QuitPopup.tscn"
