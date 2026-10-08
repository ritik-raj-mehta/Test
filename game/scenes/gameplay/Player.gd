class_name Player
extends PlayerController


# ============================================================
# MOVEMENT
# ============================================================
const SIDE_SPEED := 240.0
const TAP_KICK := 100.0
const HOP_VELOCITY := -660.0
const HOP_VELOCITY_WALL := -200.0
const GRAVITY := 1500.0
const STEER_LERP := 12.0
const DECELERATION := 900.0
const TILT_SPEED := 14.0
const TILT_LIMIT :=0.3 
const TILT_FLIP_SPEED := 8.0 

var _normal_tex: Texture2D
var _normal_scale: Vector2 = Vector2.ONE
var _normal_flip := false
var _normal_hframes: int = 3
var _tap_lock : bool = true

@export var fruit_grab_texture: Texture2D = preload("res://game/assets/sprites/atlases/node_specific/FruitGrabAnimation.png")

#@export var goal_sprite_scale: float = 2.0
#@export var goal_scale_duration: float = 0.25

@export var goal_tilt_angle: float = 12.0
@export var goal_tilt_duration: float = 0.55
# ============================================================
# GOAL
# ============================================================

@export_category("Goal Attraction")
@export var goal_attraction_speed: float = 38.0
	
const DeathEffectScript: Script = preload("res://game/scenes/gameplay/death_effect.gd")
@onready var visual: Node2D = $Sprite2D   
@onready var trail: Node2D = $Trail	
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null	
@onready var death_effect: Node2D = $DeathEffect if has_node("DeathEffect") else null
var _death_sequence_id: int = 0	
# ============================================================
# STATE
# ============================================================

var is_dead: bool = false
var is_goal_reached: bool = false
var is_goal_zooming: bool = false
var goal_target: Node2D = null
var last_move_direction: float = 0.0
var is_respawning:bool =false
var is_invulnerable: bool = false
var move_dir: float = 0.0
var _input_lock: float = 0.0

@export var goal_stop_distance: float = 60.0  
@export var goal_side_angle: float = 35.0  # degrees below horizontal
var _approach_offset := Vector2.ZERO
# ============================================================
# SIGNALS & DEPENDENCY INJECTION
# ============================================================

func _on_ready() -> void:
	if _bus:
		setup(_bus)
	refresh_skin()

func setup(bus: Node) -> void:
	_bus = bus
	if _bus:
		if _bus.has_signal("tap_locked") and not _bus.tap_locked.is_connected(_on_tap_locked):
			_bus.tap_locked.connect(_on_tap_locked)
		if _bus.has_signal("character_changed") and not _bus.character_changed.is_connected(_on_character_changed):
			_bus.character_changed.connect(_on_character_changed)
	refresh_skin()

func _on_tap_locked(locked: bool) -> void:
	_tap_lock = locked

func _on_character_changed(_character_id: String) -> void:
	refresh_skin()


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	super._ready()
	if not is_in_group("player"):
		add_to_group("player")
	if visual:
		_normal_scale = visual.scale

		var spr := visual as Sprite2D
		if spr:
			_normal_flip = spr.flip_h
		refresh_skin()

# ============================================================
# PHYSICS
# ============================================================
func _floor_bounce_velocity() -> float:
	var collision := get_last_slide_collision()
	var collider := collision.get_collider() if collision else null
	if collider and collider.has_method("get_bounce_velocity"):
		return collider.get_bounce_velocity()
	return HOP_VELOCITY
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	_input_lock = maxf(_input_lock - delta, 0.0)

	# --------------------------------------------------------
	# GOAL ATTRACTION
	# --------------------------------------------------------

	if is_goal_zooming:
		if not is_instance_valid(goal_target):
			is_goal_zooming = false
			return

		var goal_pos: Vector2 = goal_target.get_goal_position()
		var target_position: Vector2 = goal_pos + _approach_offset
		var stop: float = 0.0 if _approach_offset != Vector2.ZERO else goal_stop_distance
		var remaining: float = global_position.distance_to(target_position) - stop

		if remaining <= 2.0:
			velocity = Vector2.ZERO
			is_goal_zooming = false
			_finish_goal_sequence()
			return

		var speed: float = goal_attraction_speed
		var move_step: float = maxf(speed * delta, remaining * 1.3 * delta)

		global_position = global_position.move_toward(
			target_position,
			minf(move_step, remaining)
		)
		return

	# --------------------------------------------------------
	# NORMAL MOVEMENT
	# --------------------------------------------------------

	velocity.y += GRAVITY * delta


	# --------------------------------------------------------
	# PLATFORM BOUNCE
	# --------------------------------------------------------

	if is_on_floor() and not is_respawning:
		velocity.y = _floor_bounce_velocity()
		_play_jump_animation()


	# --------------------------------------------------------
	# KEYBOARD
	# --------------------------------------------------------
	
	_handle_keyboard_input()
	
	if is_respawning:
		velocity.x = 0.0

	elif _input_lock > 0.0:
		pass

	elif move_dir == 0.0:
	# No input -> start decelerating immediately.
		velocity.x = move_toward(
			velocity.x,
			0.0,
			DECELERATION * delta
		)

	else:
	# Input is active -> keep steering toward the selected direction.
		velocity.x = lerpf(
			velocity.x,
			move_dir * SIDE_SPEED,
			1.0 - exp(-STEER_LERP * delta)
		)

	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()
	_update_tilt(delta)
	if absf(rotation) > 0.001:
		if is_on_floor() or is_on_wall():
			rotation = 0.0
		elif _input_lock <= 0.0:
			rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-6.0 * delta))
	if _check_obstacle_collision():
		return
	is_respawning = false
	# --------------------------------------------------------
	# WALL BOUNCE
	# --------------------------------------------------------
	if is_on_wall() and not is_on_floor() :
		move_dir = sign(get_wall_normal().x)
		velocity.x = move_dir * abs(HOP_VELOCITY_WALL)
		_play_jump_animation()
	
   # vertical speed at which the tilt reaches full strength
func _update_tilt(delta: float) -> void:
	if not visual:
		return
	if _input_lock > 0.0:
		visual.rotation = 0.0
		return
	var side := signf(velocity.x) if absf(velocity.x) > 20.0 else 0.0
	var rising := velocity.y < 0.0
	var target := side * TILT_LIMIT * (1.0 if rising else -1.0)
	var k := TILT_SPEED if rising else TILT_FLIP_SPEED
	visual.rotation = lerp_angle(visual.rotation, target, 1.0 - exp(-k * delta))

func _get_haptics() -> HapticsManager:
	if not is_inside_tree():
		return null
	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if get_tree() and get_tree().root else null
	if registry and registry.has_method("get_service"):
		return registry.get_service(&"haptics") as HapticsManager
	return null


func _tap(dir: float) -> void:
	if is_dead or is_goal_reached or _input_lock > 0.0:
		return
	var haptics := _get_haptics()
	if haptics:
		haptics.light()
	SoundRegistry.play_sound(self, SoundRegistry.SOUND_JUMP)
	move_dir = dir
	last_move_direction = dir
	velocity.y = HOP_VELOCITY
	velocity.x = move_toward(velocity.x, dir * SIDE_SPEED, TAP_KICK + abs(velocity.x - dir * SIDE_SPEED) * 0.5)
	_play_jump_animation()

func _play_jump_animation() -> void:
	if visual:
		var spr := visual as Sprite2D
		if spr and spr.texture != _normal_tex:
			spr.texture = _normal_tex
			spr.hframes = _normal_hframes
	if anim_player:
		anim_player.stop()
		anim_player.play("jump")

func _input(event: InputEvent) -> void:
	if is_dead or is_goal_reached or _tap_lock:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	var w := get_viewport().get_visible_rect().size.x
	_tap(-1.0 if pos.x < w * 0.5 else 1.0)

func _handle_keyboard_input() -> void:
	if is_dead or is_goal_reached or _tap_lock:
		return
	if Input.is_action_just_pressed("move_left"):
		_tap(-1.0)
	elif Input.is_action_just_pressed("move_right"):
		_tap(1.0)


# ============================================================
# DEATH
# ============================================================
func _clear_motion_state() -> void:
	move_dir = 0.0
	last_move_direction = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0
	if anim_player:
		anim_player.stop()
	if visual:
		visual.rotation = 0.0
		var spr := visual as Sprite2D
		if spr:
			spr.frame = 0

func die() -> void:
	if is_dead:
		return
	print("DEATH START: ", Time.get_ticks_msec())
	is_dead = true
	var haptics := _get_haptics()
	if haptics:
		haptics.medium()
	SoundRegistry.play_sound(self, SoundRegistry.SOUND_DEATH)
	print("DEATH START: ", Time.get_ticks_msec())
	_death_sequence_id += 1
	var current_seq := _death_sequence_id

	if visual == null and has_node("Sprite2D"):
		visual = get_node("Sprite2D")
	if death_effect == null and has_node("DeathEffect"):
		death_effect = get_node("DeathEffect")

	_clear_motion_state()
	if trail:
		trail.stop_trail()

	if visual:
		visual.hide()

	_set_collision_active(false)
	_trigger_death_camera_shake()

	# Play split-body death effect (attractive visible pieces bursting)
	await _play_death_split_effect()

	# Guard against scene transition or external respawn during the await
	if current_seq != _death_sequence_id or not is_inside_tree():
		return

	if _bus:
		_bus.player_died.emit()
	else:
		reset_after_respawn()


func _play_death_split_effect() -> void:
	if visual == null and has_node("Sprite2D"):
		visual = get_node("Sprite2D")
	var effect: Node2D = death_effect
	if effect == null and has_node("DeathEffect"):
		effect = get_node("DeathEffect") as Node2D
		death_effect = effect
	if effect == null:
		if DeathEffectScript:
			effect = Node2D.new()
			effect.name = "DeathEffect"
			effect.set_script(DeathEffectScript)
			add_child(effect)
		death_effect = effect

	if effect and effect.has_method("play_death") and visual:
		effect.call("play_death", visual as Sprite2D, velocity)
		if effect.has_signal("finished"):
			await effect.finished
		elif is_inside_tree() and get_tree():
			await get_tree().create_timer(0.45).timeout
	elif is_inside_tree() and get_tree():
		await get_tree().create_timer(0.45).timeout



func _set_collision_active(active: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not active)


func _cleanup_death_effects() -> void:
	if death_effect and is_instance_valid(death_effect) and death_effect.has_method("clear_pieces"):
		death_effect.call("clear_pieces")


func _trigger_death_camera_shake() -> void:
	var cam := get_node_or_null("Camera2D")
	if cam and cam.has_method("shake"):
		cam.shake(9.0, 0.15)


func _play_respawn_pop_animation() -> void:
	if not visual:
		return
	visual.scale = Vector2.ZERO
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", _normal_scale * 1.25, 0.14)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "scale", _normal_scale, 0.12)


		
func _current_skin_id() -> String:
	if not is_inside_tree() or get_tree() == null:
		return SkinCatalog.DEFAULT_ID
	var registry: Node = get_tree().root.get_node_or_null("ServiceRegistry") if get_tree().root else null
	if registry and registry.has_service(&"save"):
		var save: SaveManager = registry.get_service(&"save") as SaveManager
		var progress: PlayerProgress = registry.get_service(&"player_progress") as PlayerProgress
		return PlayerSkins.resolve_equipped(save, progress)
	return SkinCatalog.DEFAULT_ID


func refresh_skin() -> void:
	if not visual:
		return
	var spr := visual as Sprite2D
	if not spr:
		return

	var skin_id := _current_skin_id()
	var jump_tex := SkinCatalog.get_jump_texture(skin_id)
	if jump_tex:
		spr.texture = jump_tex
		var w := jump_tex.get_width()
		var h := jump_tex.get_height()
		if w > h and h > 0:
			spr.hframes = int(round(float(w) / float(h)))
		else:
			spr.hframes = 1
		spr.frame = 0

		_normal_tex = spr.texture
		_normal_hframes = spr.hframes


# ============================================================
# GOAL
# ============================================================

func slow_down_at_goal(goal_node: Node2D) -> void:
	if is_goal_reached:
		return
	is_goal_reached = true
	is_goal_zooming = true
	goal_target = goal_node
	velocity = Vector2.ZERO

	# Coming from below -> park at lower-left / lower-right of the goal.
	var to_goal: Vector2 = goal_node.get_goal_position() - global_position
	_approach_offset = Vector2.ZERO
	if to_goal.y < 0.0 and absf(to_goal.x) < absf(to_goal.y) * 0.5:
		var side: float = -signf(to_goal.x)
		if side == 0.0:
			side = last_move_direction if last_move_direction != 0.0 else 1.0
		var a: float = deg_to_rad(goal_side_angle)
		_approach_offset = Vector2(side * cos(a), sin(a)) * goal_stop_distance

	_set_eat_sprite()


func _set_eat_sprite() -> void:
	var spr: Sprite2D = visual as Sprite2D

	if not spr or not is_instance_valid(goal_target):
		return

	if anim_player:
		anim_player.stop()

	spr.scale = _normal_scale
	rotation = 0.0
	visual.rotation = 0.0

	var skin_id := _current_skin_id()
	var goal_tex := SkinCatalog.get_goal_texture(skin_id)
	var tex: Texture2D = goal_tex if goal_tex else (fruit_grab_texture if fruit_grab_texture else SkinCatalog.get_eat_texture(skin_id, "right"))
	if tex:
		spr.texture = tex
		spr.hframes = 1
		spr.frame = 0

	var goal_pos: Vector2 = goal_target.get_goal_position()
	var offset: Vector2 = -_approach_offset if _approach_offset != Vector2.ZERO else goal_pos - global_position

	var snapped: float = roundf(offset.angle() / (PI / 4.0)) * (PI / 4.0)

	# FruitGrabAnimation faces RIGHT by default.
	# Goal is RIGHT -> normal (flip_h = false).
	# Goal is LEFT  -> flipped (flip_h = true).
	var goal_is_right: bool = absf(snapped) <= PI / 2.0 + 0.01
	spr.flip_h = not goal_is_right

	var target_rotation: float = (
		snapped
		if goal_is_right
		else wrapf(snapped - PI, -PI, PI)
	)

	var rotation_tween: Tween = create_tween()
	rotation_tween.set_trans(Tween.TRANS_QUAD)
	rotation_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.tween_property(visual, "rotation", target_rotation, goal_tilt_duration)


# ============================================================
# RESPAWN
# ============================================================
func reset_after_respawn() -> void:
	_death_sequence_id += 1
	set_physics_process(true)

	_clear_motion_state()
	_cleanup_death_effects()
	_set_collision_active(true)

	is_invulnerable = false
	_input_lock = 0.2
	is_respawning = true
	is_dead = false
	is_goal_reached = false
	is_goal_zooming = false
	goal_target = null

	# --------------------------------------------------------
	# RESET VISUAL TO ORIGINAL STATE
	# --------------------------------------------------------

	if anim_player:
		anim_player.stop()

	if visual:
		# Reset scale to the ORIGINAL scale captured in _ready().
		visual.scale = _normal_scale

		# Reset rotation.
		visual.rotation = 0.0

		# Reset texture.
		var spr := visual as Sprite2D
		if spr:
			refresh_skin()
			spr.flip_h = _normal_flip

	show()
	if visual:
		visual.show()

	if trail:
		trail.start_trail()

	_play_respawn_pop_animation()
	
# ============================================================
# BOOSTER
# ============================================================

func apply_directional_boost(direction: Vector2, force: float, duration: float = 0.6, boost_rotation: float = 0.0) -> void:
	if is_dead or is_goal_reached:
		return

	var haptics := _get_haptics()
	if haptics:
		haptics.medium()
	SoundRegistry.play_sound(self, SoundRegistry.SOUND_BOOSTER)

	rotation = boost_rotation
	if visual:
		visual.rotation = 0.0

	# Reset horizontal steering state so the player ascends and drops straight down
	move_dir = 0.0
	last_move_direction = 0.0

	# Zero out horizontal velocity if launched vertically (or near vertical)
	if absf(direction.x) < 0.05:
		direction.x = 0.0
		direction = direction.normalized()

	velocity = direction * force
	is_invulnerable = true
	# Only lock input momentarily at the launch base; unlock immediately once in the air
	_input_lock = 0.08
	_play_jump_animation()

	await get_tree().create_timer(duration).timeout

	if not is_dead:
		is_invulnerable = false


func apply_booster(data: Resource) -> void:
	if is_dead or is_goal_reached:
		return

	var haptics := _get_haptics()
	if haptics:
		haptics.medium()
	SoundRegistry.play_sound(self, SoundRegistry.SOUND_BOOSTER)

	if data and "boost_velocity" in data:
		print("PLAYER BOOST APPLIED: ", data.boost_velocity)
		move_dir = 0.0
		last_move_direction = 0.0
		velocity.x = 0.0
		velocity.y = data.boost_velocity
		is_invulnerable = true
		_play_jump_animation()

		var dur = data.invulnerability_duration if "invulnerability_duration" in data else 0.5
		await get_tree().create_timer(dur).timeout

		if not is_dead:
			is_invulnerable = false

# ============================================================
# KNOCKBACK & IMPULSE
# ============================================================

func apply_knockback(impulse: Vector2) -> void:
	if is_dead or is_goal_reached:
		return
	velocity = impulse


func _check_obstacle_collision() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if not collider:
			continue

		if collider is WallsController or collider.name.begins_with("Wall") or collider.is_in_group("wall"):
			continue

		if collider is ObstacleController or collider.is_in_group("obstacle") or collider.is_in_group("obstacles"):
			if collider.get("is_lethal") == false or (collider.has_meta("is_lethal") and not collider.get_meta("is_lethal")):
				continue
			die()
			return true
	return false


func _finish_goal_sequence() -> void:
	set_physics_process(false)

	if trail:
		trail.stop_trail()
	if not is_goal_reached or is_dead:
		return

	hide()
	if _bus:
		_bus.goal_sequence_finished.emit()
