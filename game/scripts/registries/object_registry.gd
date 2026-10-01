@tool
class_name ObjectRegistry
extends RefCounted

## Centralized registry for all placeable level objects, obstacles, triggers, and boundaries.
## Provides high-performance PackedScene caching, type safety, and path resolution helpers.

static var _registry: Dictionary = {
	"gear_r": {
		"id": "gear_r",
		"name": "Rotating Gear",
		"scene_path": "res://game/scenes/Obstacles/MovingGear.tscn",
		"category": "Obstacles",
		"default_properties": {"rotation_speed": 2.0},
		"default_scale": Vector2(1, 1)
	},
	"gear_m": {
		"id": "gear_m",
		"name": "Moving & Rotating Gear",
		"scene_path": "res://game/scenes/Obstacles/MovingGear.tscn",
		"category": "Obstacles",
		"default_properties": {
			"has_rod": false,
			"has_gear": true,
			"rotation_speed": 2.0,
			"move_speed": 100.0,
			"move_angle": 0.0,
			"move_dist_pos": 200.0,
			"move_dist_neg": 200.0,
			"move_distance": 200.0,
			"move_direction": "X",
			"direction_change_delay": 0.0,
			"start_delay": 0.0,
			"gear_count": 1,
			"gear_spacing": 100.0
		},
		"default_scale": Vector2(1, 1)
	},
	"gear_rod": {
		"id": "gear_rod",
		"name": "Gear Rod",
		"scene_path": "res://game/scenes/Obstacles/MovingGear.tscn",
		"category": "Obstacles",
		"default_properties": {
			"has_rod": true,
			"has_gear": false,
			"length": 200.0,
			"breadth": 8.0,
			"rod_has_collision": true,
			"gear_count": 0,
			"move_speed": 0.0,
			"rotation_speed": 0.0
		},
		"default_scale": Vector2(1, 1)
	},
	"gear_with_rod": {
		"id": "gear_with_rod",
		"name": "Moving Gear with Rod",
		"scene_path": "res://game/scenes/Obstacles/MovingGear.tscn",
		"category": "Obstacles",
		"default_properties": {
			"has_rod": true,
			"has_gear": true,
			"rotation_speed": 2.0,
			"move_speed": 150.0,
			"move_distance": 300.0,
			"move_angle": 0.0,
			"move_direction": "+X",
			"loop_reset": true,
			"rod_breadth": 8.0,
			"rod_has_collision": false,
			"gear_count": 1,
			"gear_spacing": 100.0
		},
		"default_scale": Vector2(1, 1)
	},
	"gear_path": {
		"id": "gear_path",
		"name": "Path / Shape Moving Gear",
		"scene_path": "res://game/scenes/Obstacles/PathMovingGear.tscn",
		"category": "Obstacles",
		"default_properties": {
			"path_shape": "Diamond",
			"path_width": 300.0,
			"path_height": 300.0,
			"path_rotation": 0.0,
			"move_direction": "Clockwise",
			"alternate_interval": 0.0,
			"corner_delay": 0.0,
			"move_speed": 150.0,
			"rotation_speed": 2.0,
			"gear_count": 2,
			"show_track_line": true
		},
		"default_scale": Vector2(1, 1)
	},
	"spike": {
		"id": "spike",
		"name": "Spike Trap",
		"scene_path": "res://game/scenes/Obstacles/Spike.tscn",
		"category": "Obstacles",
		"default_properties": {"rotation_speed": 0.0},
		"default_scale": Vector2(1, 1)
	},

	"goal": {
		"id": "goal",
		"name": "Goal",
		"scene_path": "res://game/scenes/Obstacles/Goal.tscn",
		"category": "Triggers",
		"default_properties": {},
		"default_scale": Vector2(1, 1)
	},
	"falling_stone": {
		"id": "falling_stone",
		"name": "Falling Stone",
		"scene_path": "res://game/scenes/Obstacles/FallingStone.tscn",
		"category": "Obstacles",
		"default_properties": {"trigger_tag": "trap_1", "fall_speed": 600.0, "rotation_speed": 4.0, "knockback_force": 600.0},
		"default_scale": Vector2(1, 1)
	},
	"falling_stone_spike": {
		"id": "falling_stone_spike",
		"name": "Falling Stone Spike",
		"scene_path": "res://game/scenes/Obstacles/FallingStoneSpike.tscn",
		"category": "Obstacles",
		"default_properties": {"trigger_tag": "trap_1", "fall_speed": 600.0, "rotation_speed": 4.0},
		"default_scale": Vector2(1, 1)
	},
	"trigger_area": {
		"id": "trigger_area",
		"name": "Trigger Area",
		"scene_path": "res://game/scenes/Obstacles/TriggerArea.tscn",
		"category": "Triggers",
		"default_properties": {"trigger_tag": "trap_1", "area_width": 200.0, "area_height": 150.0},
		"default_scale": Vector2(1, 1)
	},
	"falling_stone_trap": {
		"id": "falling_stone_trap",
		"name": "Falling Stone Trap",
		"scene_path": "res://game/scenes/Obstacles/FallingStoneTrap.tscn",
		"category": "Obstacles",
		"default_properties": {"trigger_distance_y": 300.0, "fall_speed": 600.0, "trigger_width": 200.0},
		"default_scale": Vector2(1, 1)
	},
	"horizontal_zone_start": {
		"id": "horizontal_zone_start",
		"name": "Horizontal Zone Start",
		"scene_path": "res://game/scenes/CameraDragFeatures/HorizontalZoneStart.tscn",
		"category": "Triggers",
		"default_properties": {
			"area_width": 300.0,
			"area_height": 300.0,
			"target_drag_left_margin": 0.2,
			"target_drag_right_margin": 0.2,
			"target_drag_top_margin": 0.5,
			"target_drag_bottom_margin": 0.5,
			"horizontal_drag_enabled": true,
			"vertical_drag_enabled": true,
			"transition_speed": 3.0
		},
		"default_scale": Vector2(1, 1)
	},
	"horizontal_zone_end": {
		"id": "horizontal_zone_end",
		"name": "Horizontal Zone End",
		"scene_path": "res://game/scenes/CameraDragFeatures/HorizontalZoneEnd.tscn",
		"category": "Triggers",
		"default_properties": {
			"area_width": 300.0,
			"area_height": 300.0,
			"transition_speed": 3.0
		},
		"default_scale": Vector2(1, 1)
	},
	"horizontal_zone_trigger": {
		"id": "horizontal_zone_trigger",
		"name": "Horizontal Zone Combined",
		"scene_path": "res://game/scenes/CameraDragFeatures/HorizontalZoneTrigger.tscn",
		"category": "Triggers",
		"default_properties": {
			"area_width": 300.0,
			"area_height": 300.0,
			"end_offset_x": 800.0,
			"end_offset_y": 0.0,
			"target_drag_left_margin": 0.2,
			"target_drag_right_margin": 0.2,
			"target_drag_top_margin": 0.5,
			"target_drag_bottom_margin": 0.5,
			"horizontal_drag_enabled": true,
			"vertical_drag_enabled": true,
			"transition_speed": 3.0
		},
		"default_scale": Vector2(1, 1)
	},
	"booster": {
		"id": "booster",
		"name": "Booster",
		"scene_path": "res://game/scenes/Obstacles/Booster.tscn",
		"category": "Obstacles",
		"default_properties": {"force_tier": 2, "custom_force": 0.0, "invulnerability_duration": 0.6},
		"default_scale": Vector2(1, 1)
	}
}

static var _scene_cache: Dictionary = {}

static func register_object(id: String, display_name: String, scene_path: String, category: String = "Obstacles", default_properties: Dictionary = {}, default_scale: Vector2 = Vector2.ONE) -> void:
	_registry[id] = {
		"id": id,
		"name": display_name,
		"scene_path": scene_path,
		"category": category,
		"default_properties": default_properties,
		"default_scale": default_scale
	}
	_scene_cache.erase(id)

static func unregister_object(id: String) -> void:
	_registry.erase(id)
	_scene_cache.erase(id)

static func get_all_entries() -> Dictionary:
	return _registry

static func get_entry(id: String) -> Dictionary:
	if id == "gear_rode" and not _registry.has("gear_rode"):
		id = "gear_rod"
	return _registry.get(id, {})

static func has_object(id: String) -> bool:
	if id == "gear_rode" and _registry.has("gear_rod"):
		return true
	return _registry.has(id)

static func resolve_scene_path(path: String) -> String:
	if path.ends_with("GearRod.tscn") or path.ends_with("GearRode.tscn") or path.ends_with("MovingGearWithRod.tscn") or path.ends_with("RotatingGear.tscn"):
		return "res://game/scenes/Obstacles/MovingGear.tscn"
	if ResourceLoader.exists(path):
		return path
	var goal_fix = path.replace("win_area_node.tscn", "Goal.tscn").replace("win_area.tscn", "Goal.tscn")
	if ResourceLoader.exists(goal_fix):
		return goal_fix
	# Fallback checks for migrated folders
	var legacy_to_game = path.replace("res://Obstacle/", "res://game/scenes/Obstacles/").replace("res://Scenes/", "res://game/scenes/Obstacles/").replace("res://Walls/", "res://game/scenes/Obstacles/")
	if ResourceLoader.exists(legacy_to_game):
		return legacy_to_game
	var gameplay_fallback = path.replace("res://Scenes/", "res://game/scenes/gameplay/")
	if ResourceLoader.exists(gameplay_fallback):
		return gameplay_fallback
	return path

static func get_packed_scene(id: String) -> PackedScene:
	if _scene_cache.has(id):
		return _scene_cache[id] as PackedScene

	var entry = get_entry(id)
	if entry.is_empty() or not entry.has("scene_path"):
		push_error("ObjectRegistry: Unknown object ID '%s'" % id)
		return null

	var path: String = resolve_scene_path(entry["scene_path"])
	if not ResourceLoader.exists(path):
		push_error("ObjectRegistry: Scene path '%s' does not exist" % path)
		return null

	var packed: PackedScene = load(path) as PackedScene
	if packed:
		_scene_cache[id] = packed
		return packed
	return null

static func instantiate_object(id: String) -> Node2D:
	var packed := get_packed_scene(id)
	if packed:
		var node = packed.instantiate() as Node2D
		if id == "gear_r":
			if "has_rod" in node: node.set("has_rod", false)
			if "has_gear" in node: node.set("has_gear", true)
			if "move_speed" in node: node.set("move_speed", 0.0)
			if "move_dist_pos" in node: node.set("move_dist_pos", 0.0)
			if "move_dist_neg" in node: node.set("move_dist_neg", 0.0)
			if "move_distance" in node: node.set("move_distance", 0.0)
			if "gear_count" in node: node.set("gear_count", 1)
		var entry = get_entry(id)
		if entry.has("default_properties"):
			for p in entry["default_properties"]:
				if p in node:
					node.set(p, entry["default_properties"][p])
		return node
	return null

static func clear_cache() -> void:
	_scene_cache.clear()
