class_name VerticalParallaxController
extends Node2D

## Vertical parallax with a lock.
##   LOCKED : layers sit at their start look (player hopping at the start).
##   ACTIVE : after the player climbs `unlock_height` above where it started, layers follow the camera.
##   DEAD   : player died; layers freeze while the death plays.
## On respawn the layers glide back to their start look and the controller is LOCKED again,
## measuring the climb from the respawn point.

enum State { LOCKED, ACTIVE, DEAD }

@export var camera: Camera2D
@export var layers: Array[ParallaxLayerNew] = []
@export var smooth_speed: float = 8.0

## Climb (px) above the start/respawn spot before the background starts moving.
## Keep it ABOVE a normal hop: HOP_VELOCITY^2 / (2 * GRAVITY) = 760^2 / 3000 ~ 192 px.
@export var unlock_height: float = 320.0

## How fast the background glides back to its start look after a respawn. <= 0 = instant snap.
@export var reset_speed: float = 6.0

var player: Player

var _bus: Node
var _state: State = State.LOCKED
var _baseline_pending: bool = true   # read the player's Y on the next frame (it may still be placed this frame)
var _settling: bool = false          # layers are gliding back to base_position
var _start_player_y: float = 0.0
var _camera_origin_y: float = 0.0


func setup(target_camera: Camera2D, target_player: Player, bus: Node) -> void:
	camera = target_camera
	player = target_player
	_connect_bus(bus)
	for layer in layers:
		if layer:
			layer.reset_to_base()  # new level / retry = start look, never the last run's offset
	_settling = false
	_lock()


func _process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return

	match _state:
		State.DEAD:
			if not player.is_dead:  # respawned
				_lock()
				_begin_reset()
		State.LOCKED:
			_update_locked(delta)
		State.ACTIVE:
			_update_active(delta)


func _lock() -> void:
	_state = State.LOCKED
	_baseline_pending = true


## Parallax origin goes back to the start look; layers glide (or snap) there.
func _begin_reset() -> void:
	for layer in layers:
		if layer == null:
			continue
		layer.anchor_y = layer.base_position.y
		if reset_speed <= 0.0:
			layer.position.y = layer.base_position.y
	_settling = reset_speed > 0.0


func _update_locked(delta: float) -> void:
	if _settling:
		_glide_to_base(delta)

	if _baseline_pending:
		_start_player_y = player.global_position.y
		_baseline_pending = false
		return

	if _start_player_y - player.global_position.y >= unlock_height:
		# Layers sit at their anchor (or are about to), so starting from the current camera Y causes no pop.
		_camera_origin_y = camera.global_position.y
		_settling = false
		_state = State.ACTIVE


func _glide_to_base(delta: float) -> void:
	var weight := 1.0 - exp(-reset_speed * delta)
	var done := true
	for layer in layers:
		if layer == null:
			continue
		layer.position.y = lerpf(layer.position.y, layer.base_position.y, weight)
		if absf(layer.position.y - layer.base_position.y) > 0.5:
			done = false
		else:
			layer.position.y = layer.base_position.y
	_settling = not done  # stops touching layers once everything has arrived


func _update_active(delta: float) -> void:
	var camera_delta := camera.global_position.y - _camera_origin_y
	var weight := 1.0 - exp(-smooth_speed * delta)
	for layer in layers:
		if layer == null:
			continue
		var target_y := layer.anchor_y + camera_delta * layer.parallax_factor
		layer.position.y = lerpf(layer.position.y, target_y, weight)


func _connect_bus(bus: Node) -> void:
	if bus == null or bus == _bus:
		return
	_bus = bus
	if not _bus.player_died.is_connected(_on_player_died):
		_bus.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	if _state == State.DEAD:
		return
	_settling = false
	_state = State.DEAD
