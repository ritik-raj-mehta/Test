@tool
extends Resource
class_name LevelData

@export var level_id: String = "level_001"
@export var level_name: String = "Level 1"
@export var world_theme: String = "world_1"
@export var player_start: Vector2 = Vector2(529, 1135)
@export var level_size: Vector2 = Vector2(1080, 2500)

@export var camera_drag_horizontal_enabled: bool = true
@export var camera_drag_vertical_enabled: bool = true
@export var camera_drag_horizontal_offset: float = 0.0
@export var camera_drag_vertical_offset: float = 0.0
@export var camera_drag_left_margin: float = 0.8
@export var camera_drag_top_margin: float = 0.6
@export var camera_drag_right_margin: float = 0.8
@export var camera_drag_bottom_margin: float = 0.2

@export var objects: Array[ObjectData] = []
@export var packed_tiles: PackedInt32Array = PackedInt32Array()
@export var tile_data: Array[Dictionary] = []
@export var goal_zoom: Vector2 = Vector2(1.3, 1.3)
@export var camera_follow_speed: float = 8.0


func add_object(obj_data: ObjectData) -> void:
	objects.append(obj_data)

func remove_object(obj_data: ObjectData) -> void:
	objects.erase(obj_data)

func clear_objects() -> void:
	objects.clear()

func add_packed_tile(cell_x: int, cell_y: int, atlas_x: int, atlas_y: int) -> void:
	packed_tiles.append_array([cell_x, cell_y, atlas_x, atlas_y])

func migrate_tile_data_if_needed() -> void:
	if tile_data.size() > 0:
		if packed_tiles.is_empty():
			var packed := PackedInt32Array()
			packed.resize(tile_data.size() * 4)
			var idx: int = 0
			for cell in tile_data:
				packed[idx] = int(cell.get("x", 0))
				packed[idx + 1] = int(cell.get("y", 0))
				packed[idx + 2] = int(cell.get("atlas_x", 1))
				packed[idx + 3] = int(cell.get("atlas_y", 1))
				idx += 4
			packed_tiles = packed
		tile_data.clear()
