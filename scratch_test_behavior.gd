@tool
extends SceneTree

func _init() -> void:
	print("--- STARTING FALLING STONE & TRIGGER VERIFICATION ---")

	# 1. Test instantiation and initial gameplay visibility
	var stone_scene: PackedScene = load("res://game/scenes/Obstacles/FallingStone.tscn")
	var stone: FallingStoneController = stone_scene.instantiate()
	root.add_child(stone)
	stone._ready()

	print("Initial gameplay state:")
	print("  visible: ", stone.visible, " (Expected: false)")
	print("  is_falling: ", stone.is_falling, " (Expected: false)")
	print("  col_shape disabled: ", stone.col_shape.disabled, " (Expected: true)")
	print("  col_shape radius: ", stone.col_shape.shape.radius, " (Expected: 25.0)")
	assert(stone.visible == false, "Stone must be hidden initially in gameplay")
	assert(stone.col_shape.disabled == true, "Collider must be disabled initially")
	assert(is_equal_approx(stone.col_shape.shape.radius, 25.0), "Radius must match 50px image (25.0)")

	# 2. Test spike stone radius
	stone.is_lethal = true
	print("Spike stone shape radius: ", stone.col_shape.shape.radius, " (Expected: 35.0)")
	assert(is_equal_approx(stone.col_shape.shape.radius, 35.0), "Spike stone radius must match 70px image (35.0)")
	stone.is_lethal = false

	# 3. Test trigger activation
	stone.trigger()
	print("Post-trigger state:")
	print("  visible: ", stone.visible, " (Expected: true)")
	print("  is_falling: ", stone.is_falling, " (Expected: true)")
	print("  velocity.y: ", stone.velocity.y, " (Expected: 600.0)")
	assert(stone.visible == true, "Stone must be shown when triggered")
	assert(stone.is_falling == true, "Stone must be falling when triggered")
	assert(stone.velocity.y == 600.0, "Stone initial downward velocity must be fall_speed")

	# 4. Test normal stone collision with player: opposite direction rebound
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.global_position = Vector2(0, 100) # Player is below stone
	stone.global_position = Vector2(0, 50)   # Stone is at Y=50
	root.add_child(player)

	# Simulate collision
	stone._handle_player_collision(player)
	print("Collision reaction:")
	print("  Player velocity: ", player.velocity)
	print("  Stone velocity: ", stone.velocity)
	assert(player.velocity.y > 0, "Player must be knocked downward away from stone")
	assert(stone.velocity.y < 0, "Stone must rebound UPWARD in opposite direction")
	
	# Verify stone rebounds in opposite direction
	var player_dir = player.velocity.normalized()
	var stone_dir = stone.velocity.normalized()
	var dot = player_dir.dot(stone_dir)
	print("  Dot product between player push and stone rebound: ", dot, " (Expected: close to -1.0)")
	assert(dot < -0.9, "Stone must rebound in opposite direction of player impulse")

	# 5. Test that stone starts falling down again due to gravity
	print("Testing gravity pulling stone back down:")
	var prev_vy = stone.velocity.y
	for frame in range(60):
		stone._physics_process(1.0 / 60.0)
	print("  Stone velocity.y after 1 second under gravity: ", stone.velocity.y)
	assert(stone.velocity.y > 0, "Stone must be falling back down under gravity after rebound")

	# 6. Test landing and 2-second deactivation
	stone.has_landed = true
	stone.velocity = Vector2.ZERO
	stone._physics_process(1.0)
	assert(stone.visible == true, "Stone still visible after 1.0s")
	stone._physics_process(1.1)
	print("Stone state after 2.1s at rest:")
	print("  visible: ", stone.visible, " (Expected: false)")
	print("  is_falling: ", stone.is_falling, " (Expected: false)")
	assert(stone.visible == false, "Stone must be deactivated/hidden after 2 seconds at rest")

	# 7. Test reset() restores state and hides stone again
	stone.reset()
	print("Stone state after reset():")
	print("  visible: ", stone.visible, " (Expected: false)")
	print("  global_position: ", stone.global_position, " (Expected: ", stone.start_pos, ")")
	assert(stone.visible == false, "Stone must be hidden again on reset")

	# Clean up
	stone.queue_free()
	player.queue_free()

	print("--- ALL VERIFICATIONS PASSED SUCCESSFULLY! ---")
	quit(0)
