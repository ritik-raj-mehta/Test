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

const TILT_SPEED := 14.0
const TILT_LIMIT :=0.3 
const TILT_FLIP_SPEED := 8.0 


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
const STEER_LERP := 12.0
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

		var distance: float = global_position.distance_to(target_position)

		var speed: float = goal_attraction_speed

		if distance < 100.0:
			speed *= 0.5

		if distance < 40.0:
			speed *= 0.25

		global_position = global_position.move_toward(
			target_position,
			speed * delta
		)

		if global_position.distance_to(target_position) <= 5.0:
			global_position = target_position
			velocity = Vector2.ZERO
			is_goal_zooming = false
			_finish_goal_sequence()
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
	else:
		velocity.x = lerpf(velocity.x, move_dir * SIDE_SPEED, 1.0 - exp(-STEER_LERP * delta))

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

	velocity = direction * force
	is_invulnerable = true
	_input_lock = duration

	await get_tree().create_timer(duration).timeout

	if not is_dead:
		is_invulnerable = false


func apply_booster(data: Resource) -> void:
	if is_dead or is_goal_reached:
		return

	if data and "boost_velocity" in data:
		print("PLAYER BOOST APPLIED: ", data.boost_velocity)
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
	hide()
	if _bus:
		_bus.goal_sequence_finished.emit()
