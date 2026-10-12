extends GutTest

## The `Minigame` base itself: run flag, finish-once, the shared skip handler
## and the countdown. Scene-level pins of the same contract live in
## test_minigame_contract.gd.


## Overrides `_process` on purpose: Godot 4 never calls a parent's `_process`
## once a subclass defines its own, so the countdown must not depend on it.
class Probe extends Minigame:
	var frames: int = 0
	var timeouts: int = 0

	func _process(_delta: float) -> void:
		frames += 1

	func _on_timeout() -> void:
		timeouts += 1


func _probe() -> Probe:
	var probe := Probe.new()
	add_child_autofree(probe)
	watch_signals(probe)
	return probe


func test_finish_reports_once_even_when_called_twice() -> void:
	var probe := _probe()
	probe._finish(0.4)
	probe._finish(0.9)
	assert_signal_emit_count(probe, "finished", 1)
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 0.4, "skipped": false}])


func test_finish_with_after_a_finish_reports_nothing() -> void:
	var probe := _probe()
	probe._finish(0.4)
	probe._finish_with({"choice": "cook"})
	assert_signal_emit_count(probe, "finished", 1)


func test_finish_with_merges_extras_over_a_full_score() -> void:
	var probe := _probe()
	probe._finish_with({"choice": "cook"})
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 1.0, "skipped": false, "choice": "cook"}])


func test_finish_clamps_the_score_into_0_1() -> void:
	var probe := _probe()
	probe._finish(1.7)
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 1.0, "skipped": false}])


func test_a_game_is_not_running_until_it_starts() -> void:
	var probe := _probe()
	assert_false(probe.is_running())
	probe._start()
	assert_true(probe.is_running())


func test_finishing_stops_the_run_and_a_restart_cannot_revive_it() -> void:
	var probe := _probe()
	probe._start()
	probe._finish(1.0)
	assert_false(probe.is_running())
	probe._start()
	assert_false(probe.is_running(), "a finished game stays finished")


func test_skip_before_the_game_starts_reports_nothing() -> void:
	var probe := _probe()
	probe._on_skip_pressed()
	assert_signal_not_emitted(probe, "finished")


func test_skip_while_running_reports_a_zero_skipped_result_once() -> void:
	var probe := _probe()
	probe._start()
	probe._on_skip_pressed()
	probe._on_skip_pressed()
	assert_signal_emit_count(probe, "finished", 1)
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 0.0, "skipped": true}])
	assert_false(probe.is_running())


func test_no_countdown_reads_as_no_time() -> void:
	var probe := _probe()
	assert_eq(probe.time_left(), 0.0)
	assert_eq(probe.time_fraction(), 0.0)


func test_a_fresh_countdown_reads_full() -> void:
	var probe := _probe()
	probe._start_countdown(10.0)
	assert_eq(probe.time_left(), 10.0)
	assert_eq(probe.time_fraction(), 1.0)


func test_the_countdown_runs_while_the_subclass_has_its_own_process() -> void:
	var probe := _probe()
	probe._start()
	probe._start_countdown(100.0)
	await wait_process_frames(5)
	assert_gt(probe.frames, 0, "precondition: the subclass _process ran")
	assert_lt(probe.time_left(), 100.0, "the countdown ticked despite the override")
	assert_gt(probe.time_fraction(), 0.0)
	assert_lt(probe.time_fraction(), 1.0)
	assert_eq(probe.timeouts, 0, "a 100 s countdown cannot have run out")


func test_the_countdown_times_out_exactly_once_and_reads_empty() -> void:
	var probe := _probe()
	probe._start()
	probe._start_countdown(0.05)
	await wait_seconds(0.3)
	assert_eq(probe.timeouts, 1)
	assert_eq(probe.time_left(), 0.0)
	assert_eq(probe.time_fraction(), 0.0)


func test_finishing_stops_the_countdown() -> void:
	var probe := _probe()
	probe._start()
	probe._start_countdown(0.05)
	probe._finish(1.0)
	await wait_seconds(0.3)
	assert_eq(probe.timeouts, 0, "a finished game never times out")
