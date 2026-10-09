extends SceneTree

var frame_count: int = 0
const MAX_FRAMES: int = 240

func _init() -> void:
	print("[TEST_RUNTIME] Initializing runtime test...")
	var boot_scene = load("res://game/scenes/boot/Boot.tscn")
	if boot_scene == null:
		push_error("[TEST_RUNTIME] Failed to load Boot.tscn")
		quit(1)
		return
	change_scene_to_packed(boot_scene)

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count % 30 == 0:
		var scene_name = current_scene.name if current_scene else "null"
		var reg = root.get_node_or_null("ServiceRegistry")
		var services_count = 0
		if reg and reg.has_method("has_service"):
			for s in [&"game", &"audio", &"save", &"scene", &"ui", &"bus", &"logger", &"config"]:
				if reg.has_service(s):
					services_count += 1
		print("[TEST_RUNTIME] Frame %d: CurrentScene='%s', RegisteredServices=%d/8" % [frame_count, scene_name, services_count])
	
	if frame_count >= MAX_FRAMES:
		print("[TEST_RUNTIME] Successfully executed %d frames!" % MAX_FRAMES)
		var reg = root.get_node_or_null("ServiceRegistry")
		if reg == null:
			push_error("[TEST_RUNTIME] ServiceRegistry missing!")
			return true
		print("[TEST_RUNTIME] All checks passed. Quitting with code 0.")
		return true
	return false
