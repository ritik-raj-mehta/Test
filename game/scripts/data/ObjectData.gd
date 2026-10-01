@tool
extends Resource
class_name ObjectData

@export var object_id: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var rotation: float = 0.0 # in degrees
@export var scale: Vector2 = Vector2.ONE
@export var properties: Dictionary = {}

func _init(p_id: String = "", p_pos: Vector2 = Vector2.ZERO, p_rot: float = 0.0, p_scale: Vector2 = Vector2.ONE, p_props: Dictionary = {}) -> void:
	object_id = p_id
	position = p_pos
	rotation = p_rot
	scale = p_scale
	properties = p_props.duplicate(true)

func duplicate_data() -> ObjectData:
	return ObjectData.new(object_id, position, rotation, scale, properties.duplicate(true))
