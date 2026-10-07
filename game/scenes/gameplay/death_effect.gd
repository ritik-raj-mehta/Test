class_name DeathEffect
extends Node2D

## Emitted when all pieces and burst particles have finished animating
signal finished

@export var columns: int = 4
@export var rows: int = 5

@export var duration: float = 0.45
@export var gravity: float = 1900.0
@export var burst_speed_min: float = 520.0
@export var burst_speed_max: float = 950.0
@export var upward_pop_min: float = 0.30
@export var upward_pop_max: float = 0.80
@export var angular_speed_max: float = 28.0

@export var blast_distance_min: float = 50.0
@export var blast_distance_max: float = 120.0
@export var animation_duration: float = 0.45
@export var rotation_min: float = -3.0
@export var rotation_max: float = 3.0

var _pieces: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []
var _elapsed: float = 0.0
var _is_animating: bool = false

const SPARKLE_COLORS: Array[Color] = [
	Color("#FFE066"), # Vibrant gold
	Color("#FF8C42"), # Juicy orange
	Color("#FFFFFF"), # Crisp bright white
	Color("#FF6584"), # Radiant pink
	Color("#64D8CB"), # Neon cyan
	Color("#FFD166")  # Warm amber
]


func _ready() -> void:
	set_process(false)
	top_level = true
	z_index = 25


## Backward-compatible signature
func play(source_sprite: Sprite2D) -> void:
	play_death(source_sprite, Vector2.ZERO)


## Main attractive death burst method
func play_death(source_sprite: Sprite2D, player_velocity: Vector2 = Vector2.ZERO) -> void:
	if source_sprite == null or source_sprite.texture == null:
		finished.emit()
		return

	clear_pieces()

	global_position = source_sprite.global_position
	rotation = 0.0
	scale = Vector2.ONE
	_elapsed = 0.0
	_is_animating = true
	set_process(true)

	var tex: Texture2D = source_sprite.texture
	var h_f: int = maxi(1, source_sprite.hframes)
	var v_f: int = maxi(1, source_sprite.vframes)
	var cur_frame: int = source_sprite.frame

	var frame_w: float = float(tex.get_width()) / float(h_f)
	var frame_h: float = float(tex.get_height()) / float(v_f)

	var col_f: int = cur_frame % h_f
	var row_f: int = cur_frame / h_f

	var frame_x: float = float(col_f) * frame_w
	var frame_y: float = float(row_f) * frame_h

	var piece_w: float = frame_w / float(columns)
	var piece_h: float = frame_h / float(rows)

	var img: Image = null
	if tex.has_method("get_image"):
		img = tex.get_image()

	for r in range(rows):
		for c in range(columns):
			var rx: float = frame_x + float(c) * piece_w
			var ry: float = frame_y + float(r) * piece_h

			# Alpha sampling: skip pieces that only contain blank transparent air
			if img != null:
				var has_pixel: bool = false
				for sx in [0.25, 0.5, 0.75]:
					for sy in [0.25, 0.5, 0.75]:
						var px: int = int(clampf(rx + sx * piece_w, 0.0, float(tex.get_width() - 1)))
						var py: int = int(clampf(ry + sy * piece_h, 0.0, float(tex.get_height() - 1)))
						if img.get_pixel(px, py).a > 0.06:
							has_pixel = true
							break
					if has_pixel:
						break
				if not has_pixel:
					continue

			# Create piece sprite with region rect
			var piece: Sprite2D = Sprite2D.new()
			piece.texture = tex
			piece.region_enabled = true
			piece.region_rect = Rect2(rx, ry, piece_w, piece_h)
			piece.centered = true
			piece.flip_h = source_sprite.flip_h
			piece.modulate = source_sprite.modulate
			piece.z_index = 25

			var unscaled_x: float = -frame_w * 0.5 + (float(c) + 0.5) * piece_w
			var unscaled_y: float = -frame_h * 0.5 + (float(r) + 0.5) * piece_h
			if source_sprite.flip_h:
				unscaled_x = -unscaled_x

			var piece_local_pos: Vector2 = (Vector2(unscaled_x, unscaled_y) * source_sprite.scale).rotated(source_sprite.rotation)
			piece.position = piece_local_pos
			piece.rotation = source_sprite.rotation
			piece.scale = source_sprite.scale

			add_child(piece)

			# Calculate juicy radial burst velocity with upward arc bias
			var out_dir: Vector2 = piece_local_pos
			if out_dir.length_squared() < 4.0:
				out_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			out_dir = out_dir.normalized()
			out_dir.y -= randf_range(upward_pop_min, upward_pop_max)
			out_dir = out_dir.normalized()

			var spd: float = randf_range(burst_speed_min, burst_speed_max)
			var vel: Vector2 = out_dir * spd + player_velocity * 0.2
			var ang: float = randf_range(-angular_speed_max, angular_speed_max)

			_pieces.append({
				"sprite": piece,
				"vel": vel,
				"ang_vel": ang,
				"base_scale": source_sprite.scale
			})

	# Spawn vibrant pop sparkles
	var sparkle_count: int = randi_range(16, 22)
	for i in range(sparkle_count):
		var ang: float = randf_range(0.0, TAU)
		var spd: float = randf_range(550.0, 1050.0)
		var s_vel: Vector2 = Vector2(cos(ang), sin(ang)) * spd
		s_vel.y -= randf_range(120.0, 320.0)
		var col: Color = SPARKLE_COLORS[randi() % SPARKLE_COLORS.size()]
		_sparkles.append({
			"pos": Vector2.ZERO,
			"vel": s_vel,
			"color": col,
			"size": randf_range(3.5, 6.5),
			"life": randf_range(0.24, 0.38)
		})

	queue_redraw()


func _process(delta: float) -> void:
	if not _is_animating:
		return

	_elapsed += delta

	# 1. Update body pieces motion, spin, and fade-out
	var fade_start: float = duration * 0.45
	var fade_len: float = duration - fade_start
	var is_fading: bool = _elapsed > fade_start

	for p in _pieces:
		var spr: Sprite2D = p.sprite
		if not is_instance_valid(spr):
			continue

		p.vel.y += gravity * delta
		p.vel.x *= (1.0 - 0.4 * delta)
		spr.position += p.vel * delta
		spr.rotation += p.ang_vel * delta

		if is_fading:
			var f: float = clampf(1.0 - ((_elapsed - fade_start) / fade_len), 0.0, 1.0)
			var ease_f: float = f * f
			spr.scale = p.base_scale * ease_f
			spr.modulate.a = ease_f

	# 2. Update pop sparkles
	for sp in _sparkles:
		sp.vel.y += (gravity * 0.25) * delta
		sp.vel.x *= (1.0 - 1.5 * delta)
		sp.pos += sp.vel * delta

	queue_redraw()

	# 3. Check completion
	if _elapsed >= duration:
		_is_animating = false
		set_process(false)
		clear_pieces()
		queue_redraw()
		finished.emit()


func _draw() -> void:
	if not _is_animating:
		return

	# Shockwave ring
	if _elapsed < 0.18:
		var rf: float = _elapsed / 0.18
		var r_radius: float = lerpf(12.0, 95.0, rf)
		var r_alpha: float = (1.0 - rf) * 0.95
		var r_width: float = lerpf(4.5, 1.0, rf)
		var col: Color = Color(1.0, 0.95, 0.8, r_alpha)
		draw_arc(Vector2.ZERO, r_radius, 0.0, TAU, 32, col, r_width, true)

	# Pop sparkles
	for sp in _sparkles:
		if _elapsed < sp.life:
			var sf: float = 1.0 - (_elapsed / sp.life)
			var c: Color = sp.color
			c.a = sf
			var cur_size: float = sp.size * sf
			draw_circle(sp.pos, cur_size, c)
			draw_circle(sp.pos, cur_size * 0.45, Color(1, 1, 1, sf))


func clear_pieces() -> void:
	for p in _pieces:
		if is_instance_valid(p.sprite):
			p.sprite.queue_free()
	_pieces.clear()
	_sparkles.clear()
	_is_animating = false
	set_process(false)
	queue_redraw()
