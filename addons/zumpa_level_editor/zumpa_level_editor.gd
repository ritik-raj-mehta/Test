@tool
extends EditorPlugin

const EDITOR_SCENE = preload("res://addons/zumpa_level_editor/level_editor.tscn")
var editor_instance: Control

func _enter_tree() -> void:
	editor_instance = EDITOR_SCENE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(editor_instance)
	_make_visible(false)

func _exit_tree() -> void:
	if editor_instance:
		editor_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor_instance:
		editor_instance.visible = visible

func _get_plugin_name() -> String:
	return "Level Editor"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Node2D", "EditorIcons")
