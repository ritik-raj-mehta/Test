extends Node
class_name GameBus
# GameBus — global signal bus
# Nothing talks to each other directly — everything goes through signals here
#
# Features receive this bus through explicit dependency setup.

# ── Player ────────────────────────────────────────────────────────────────
signal player_died
signal player_respawned
signal score_changed(new_score: int)
signal health_changed(new_health: int, max_health: int)
signal tap_locked(locked: bool)

# ── Game State ────────────────────────────────────────────────────────────
signal game_started
signal game_paused
signal game_resumed
signal game_over(reason: String)
signal level_started(level_id: String)
signal level_completed(level_id: String)
signal goal_reached(player: Node2D, goal: Node2D)
signal goal_sequence_finished
signal tap_tap_started
signal tap_tap_completed(progress_before: float, progress_after: float)

signal character_completed(character_id: String)
signal character_changed(character_id: String)
# ── Economy ───────────────────────────────────────────────────────────────
signal coins_changed(new_amount: int)
signal item_unlocked(item_id: String)
signal purchase_completed(product_id: String)

# ── UI ────────────────────────────────────────────────────────────────────
signal screen_opened(screen_name: String)
signal screen_closed(screen_name: String)
signal world_focused(world_index: int)

# ── Network & Persistence ─────────────────────────────────────────────────
signal auth_completed(uid: String)
signal auth_failed(reason: String)
signal save_loaded
signal save_saved
signal sync_started
signal sync_completed
signal sync_failed(reason: String)

func configure(data_signals: Node) -> void:
	if data_signals == null:
		return
	data_signals.sync_started.connect(func(): sync_started.emit())
	data_signals.sync_finished.connect(func(res):
		if res and res.success:
			sync_completed.emit()
		else:
			var err_msg = res.error_message if res else "Unknown sync error"
			sync_failed.emit(err_msg)
	)
	data_signals.save_finished.connect(func(res):
		if res and res.success:
			save_saved.emit()
	)
	data_signals.login_changed.connect(func(uid: String, is_auth: bool):
		if is_auth and not uid.is_empty():
			auth_completed.emit(uid)
	)

func _ready() -> void:
	pass
