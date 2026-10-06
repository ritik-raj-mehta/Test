extends Control
class_name RingProgress

signal countdown_finished

@onready var ring: TextureProgressBar = $Ring
@onready var number_label: Label = $TextureRect/Label

@export var countdown_time: float = 3.0

var time_left: float = 0.0
var countdown_active: bool = false
var countdown_paused: bool = false

func start_countdown() -> void:
	print("RING: START COUNTDOWN")

	time_left = countdown_time
	countdown_active = true

	ring.value = 100.0
	number_label.text = str(ceili(time_left))

func pause_countdown() -> void:
	print("RING: COUNTDOWN PAUSED")
	countdown_paused = true

func _process(delta: float) -> void:
	if not countdown_active:
		return
	if countdown_paused:
		return

	time_left -= delta

	ring.value = maxf(
		(time_left / countdown_time) * 100.0,
		0.0
	)

	var current_number: int = maxi(
		1,
		ceili(time_left)
	)

	number_label.text = str(current_number)

	if time_left <= 0.0:
		time_left = 0.0
		countdown_active = false
		ring.value = 0.0

		print("RING: COUNTDOWN FINISHED")

		countdown_finished.emit()
