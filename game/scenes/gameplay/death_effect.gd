extends Node2D


@export var columns: int = 3
@export var rows: int = 3

@export var blast_distance_min: float = 50.0
@export var blast_distance_max: float = 120.0

@export var animation_duration: float = 0.45

@export var rotation_min: float = -3.0
@export var rotation_max: float = 3.0


func play(source_sprite: Sprite2D) -> void:

	if source_sprite == null:
		return

	if source_sprite.texture == null:
		return

	# Remove pieces from previous death
	clear_pieces()

	# Create pieces from the player's current texture
	create_pieces(source_sprite)

	# Hide the original player
	source_sprite.visible = false

	# Blast the pieces
	blast_pieces()


func create_pieces(source_sprite: Sprite2D) -> void:

	var texture: Texture2D = source_sprite.texture
	var texture_size: Vector2 = texture.get_size()

	var piece_width: float = texture_size.x / float(columns)
	var piece_height: float = texture_size.y / float(rows)

	for y in range(rows):

		for x in range(columns):

			var piece: Sprite2D = Sprite2D.new()

			piece.texture = texture
			piece.region_enabled = true

			piece.region_rect = Rect2(
				x * piece_width,
				y * piece_height,
				piece_width,
				piece_height
			)

			piece.centered = true
			piece.scale = source_sprite.scale

			var piece_offset: Vector2 = Vector2(
				(x + 0.5) * piece_width - texture_size.x / 2.0,
				(y + 0.5) * piece_height - texture_size.y / 2.0
			)

			piece.position = (
				source_sprite.position
				+ piece_offset * source_sprite.scale
			)

			add_child(piece)


func blast_pieces() -> void:

	for child in get_children():

		if not child is Sprite2D:
			continue

		var piece: Sprite2D = child

		var direction := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		var distance := randf_range(
			blast_distance_min,
			blast_distance_max
		)

		var target_position := (
			piece.position + direction * distance
		)

		var target_rotation := randf_range(
			rotation_min,
			rotation_max
		)

		var tween := create_tween()

		tween.set_parallel(true)

		# Move immediately and smoothly
		tween.tween_property(
			piece,
			"position",
			target_position,
			0.25
		).set_trans(
			Tween.TRANS_LINEAR
		).set_ease(
			Tween.EASE_OUT
		)

		# Rotate immediately
		tween.tween_property(
			piece,
			"rotation",
			target_rotation,
			0.25
		).set_trans(
			Tween.TRANS_LINEAR
		).set_ease(
			Tween.EASE_OUT
		)

		# Fade smoothly
		tween.tween_property(
			piece,
			"modulate:a",
			0.0,
			0.25
		)


func clear_pieces() -> void:

	for child in get_children():

		if child is Sprite2D:
			child.queue_free()
