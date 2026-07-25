extends GutTest

## Scene-level smoke: walk main.tscn through every slot of a day by faking each
## minigame's finished signal. Catches host wiring, per-slot params and the
## summary hand-off — not per-minigame behaviour, which its own suite covers.

const FAKE_RESULTS := {
	"dinner": {"score": 1.0, "skipped": false, "choice": "cook"},
	"freetime": {"score": 0.33, "skipped": false, "choice": "logoff", "games_played": 2},
}


## Last child, NOT child 0: game.gd queue_free()s the outgoing minigame, and
## queue_free defers the actual removal past the end of this synchronous loop,
## so finished slots pile up at the front of the host. Do not "simplify" this
## to get_child(0) — it would hand back an already-freed minigame.
func _current_minigame(host: Control) -> Minigame:
	return host.get_child(host.get_child_count() - 1)


func test_a_whole_day_runs_through_to_the_summary() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var host: Control = main.get_node("%MinigameHost")
	for slot in DaySchedule.SLOTS:
		var node := _current_minigame(host)
		assert_not_null(node, "a minigame is hosted for slot %s" % slot)
		node.finished.emit(FAKE_RESULTS.get(slot, {"score": 1.0, "skipped": false}))
	var summary: Panel = main.get_node("%Summary")
	assert_true(summary.visible, "the day ends on the summary panel")


func test_freetime_games_decide_the_bedtime_the_sleep_beat_narrates() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var host: Control = main.get_node("%MinigameHost")
	for slot in DaySchedule.SLOTS:
		_current_minigame(host).finished.emit(
			FAKE_RESULTS.get(slot, {"score": 1.0, "skipped": false})
		)
	assert_eq(main.state.bedtime, "late", "two games played means a late night")
	assert_true(main.state.played_late)
