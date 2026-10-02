extends CharacterBody2D
class_name Player


# ============================================================
# MOVEMENT
# ============================================================
const SIDE_SPEED := 380.0
const TAP_KICK := 160.0
const HOP_VELOCITY := -760.0
const HOP_VELOCITY_WALL := -380.0
const GRAVITY := 1500.0
const STEER_LERP := 12.0
const DECELERATION := 900.0
const TILT_SPEED := 14.0
const TILT_LIMIT :=0.3 
const TILT_FLIP_SPEED := 8.0 

var _normal_tex: Texture2D
var _normal_scale: Vector2 = Vector2.ONE
var _normal_flip := false

@export var goal_sprite_scale: float = 2.0
@export var goal_scale_duration: float = 0.25

@export var goal_tilt_angle: float = 12.0
@export var goal_tilt_duration: float = 0.15
# ============================================================
# GOAL
# ============================================================

@export_category("Goal Attraction")
@export var goal_attraction_speed: float = 120.0
	
@onready var visual: Node2D = $Sprite2D   
@onready var trail: Node2D = $Trail	
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

@export var goal_stop_distance: float = 35.0  
# ============================================================
# SIGNALS
# ============================================================

var _bus: GameBus   # use Node if GameBus has no class_name

func setup(bus: GameBus) -> void:
	_bus = bus


# ============================================================
# READY
# ============================================================

#func _ready() -> void:
	#update_background_transform()
func _ready() -> void:
	if visual:
		_normal_scale = visual.scale

		var spr := visual as Sprite2D
		if spr:
			_normal_tex = spr.texture
			_normal_flip = spr.flip_h

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

		var target_position: Vector2 = goal_target.get_goal_position()
		var remaining: float = global_position.distance_to(target_position) - goal_stop_distance

		if remaining <= 2.0:
			velocity = Vector2.ZERO
			is_goal_zooming = false
			_finish_goal_sequence()
			return

		var speed: float = goal_attraction_speed

		if remaining < 100.0:
			speed *= 0.5

		if remaining < 25.0:
			speed *= 0.5

		global_position = global_position.move_toward(
			target_position,
			minf(speed * delta, remaining)
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

func _tap(dir: float) -> void:
	if is_dead or is_goal_reached or _input_lock > 0.0:
		return
	move_dir = dir
	last_move_direction = dir
	velocity.y = HOP_VELOCITY
	velocity.x = move_toward(velocity.x, dir * SIDE_SPEED, TAP_KICK + abs(velocity.x - dir * SIDE_SPEED) * 0.5)

func _input(event: InputEvent) -> void:
	if is_dead or is_goal_reached:
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
	if is_dead or is_goal_reached:
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
	if visual:
		visual.rotation = 0.0

func die() -> void:
	if is_dead:
		return
	is_dead = true
	_clear_motion_state()
	if trail:
		trail.stop_trail()
	hide()
	if _bus:
		_bus.player_died.emit()


func _play_eat() -> void:
	if not is_instance_valid(goal_target):
		return
	var dir := global_position.direction_to(goal_target.get_goal_position())
	var base := visual.scale
	var t := create_tween()
	t.tween_property(self, "global_position", global_position + dir * 18.0, 0.1)
	t.tween_callback(goal_target.on_eaten)
	for i in 3:
		t.tween_property(visual, "scale", base * Vector2(1.25, 0.8), 0.07)
		t.tween_property(visual, "scale", base * Vector2(0.9, 1.1), 0.07)
	t.tween_property(visual, "scale", base, 0.05)
	await t.finished

		
func _current_skin_id() -> String:
	return SkinCatalog.DEFAULT_ID
# ============================================================
# GOAL
# ============================================================

#func slow_down_at_goal(goal_node: Node2D) -> void:
	#if is_goal_reached:
		#return	
	#is_goal_reached = true
	#is_goal_zooming = true
	#goal_target = goal_node
	#velocity = Vector2.ZERO
func slow_down_at_goal(goal_node: Node2D) -> void:
	if is_goal_reached:
		return
	is_goal_reached = true
	is_goal_zooming = true
	goal_target = goal_node
	velocity = Vector2.ZERO
	_set_eat_sprite()

	
func _set_eat_sprite() -> void:
	var spr: Sprite2D = visual as Sprite2D

	if not spr or not is_instance_valid(goal_target):
		return

	# Always start from the original scale.
	spr.scale = _normal_scale

	visual.rotation = 0.0

	var goal_position: Vector2 = goal_target.get_goal_position()

	# ========================================================
	# EAT SPRITE
	# ========================================================

	# eat_right visually faces LEFT.
	var tex: Texture2D = SkinCatalog.get_eat_texture(
		_current_skin_id(),
		"right"
	)

	if tex:
		spr.texture = tex

	# eat_right faces LEFT.
	# Goal LEFT  -> normal
	# Goal RIGHT -> flip horizontally
	spr.flip_h = goal_position.x > global_position.x


		# ========================================================
	# TILT TOWARDS GOAL (8 directions)
	# ========================================================
	rotation = 0.0
	var offset: Vector2 = goal_position - global_position
	var snapped: float = roundf(offset.angle() / (PI / 4.0)) * (PI / 4.0)

	var goal_is_right: bool = offset.x >= 0.0
	spr.flip_h = goal_is_right

	# Sprite faces LEFT unflipped, RIGHT when flipped.
	var target_rotation: float = snapped if goal_is_right else wrapf(snapped - PI, -PI, PI)

	var rotation_tween: Tween = create_tween()
	rotation_tween.set_trans(Tween.TRANS_QUAD)
	rotation_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.tween_property(visual, "rotation", target_rotation, goal_tilt_duration)

	# ========================================================
	# GOAL SCALE
	# ========================================================

	var target_scale: Vector2 = _normal_scale * goal_sprite_scale

	var scale_tween: Tween = create_tween()

	scale_tween.set_trans(Tween.TRANS_QUAD)
	scale_tween.set_ease(Tween.EASE_OUT)

	scale_tween.tween_property(
		visual,
		"scale",
		target_scale,
		goal_scale_duration
	)
# ============================================================
# RESPAWN
# ============================================================
func reset_after_respawn() -> void:
	set_physics_process(true)

	_clear_motion_state()

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

	if visual:
		# Reset scale to the ORIGINAL scale captured in _ready().
		visual.scale = _normal_scale

		# Reset rotation.
		visual.rotation = 0.0

		# Reset texture.
		var spr := visual as Sprite2D
		if spr:
			spr.texture = _normal_tex
			spr.flip_h = _normal_flip

	show()

	if trail:
		trail.start_trail()
	
# ============================================================
# BOOSTER
# ============================================================

func apply_directional_boost(direction: Vector2, force: float, duration: float = 0.6, boost_rotation: float = 0.0) -> void:
	if is_dead or is_goal_reached:
		return

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

	await get_tree().create_timer(duration).timeout

	if not is_dead:
		is_invulnerable = false


func apply_booster(data: Resource) -> void:
	if is_dead or is_goal_reached:
		return

	if data and "boost_velocity" in data:
		print("PLAYER BOOST APPLIED: ", data.boost_velocity)
		move_dir = 0.0
		last_move_direction = 0.0
		velocity.x = 0.0
		velocity.y = data.boost_velocity
		is_invulnerable = true

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

		if collider is ObstacleController or collider.is_in_group("obstacle"):
			if collider.get("is_lethal") == false or (collider.has_meta("is_lethal") and not collider.get_meta("is_lethal")):
				continue
			die()
			return true
	return false

func _finish_goal_sequence() -> void:
	set_physics_process(false)   # otherwise gravity resumes and it falls away from the goal
	if trail:
		trail.stop_trail()
	await _play_eat()
	if not is_goal_reached or is_dead:   # respawned during the eat
		return
	hide()
	if _bus:
		_bus.goal_sequence_finished.emit()
