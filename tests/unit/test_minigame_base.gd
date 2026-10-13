extends GutTest

## The `Minigame` base itself: run flag, finish-once, the shared skip handler,
## the countdown, the time_limit param and the fail gag. Scene-level pins of the
## same contract live in test_minigame_contract.gd.


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
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 0.4, "skipped": false, "failed": false}])


func test_finish_with_after_a_finish_reports_nothing() -> void:
	var probe := _probe()
	probe._finish(0.4)
	probe._finish_with({"choice": "cook"})
	assert_signal_emit_count(probe, "finished", 1)


func test_finish_with_merges_extras_over_a_full_score() -> void:
	var probe := _probe()
	probe._finish_with({"choice": "cook"})
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 1.0, "skipped": false, "failed": false, "choice": "cook"}])


func test_finish_clamps_the_score_into_0_1() -> void:
	var probe := _probe()
	probe._finish(1.7)
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 1.0, "skipped": false, "failed": false}])


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
	assert_eq(get_signal_parameters(probe, "finished"), [{"score": 0.0, "skipped": true, "failed": false}])
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


## A gag short enough for a headless wait; the real one is 1-2 s.
const QUICK_GAG := {"fail_gag_seconds": 0.05}
const FAILED := {"score": 0.0, "skipped": false, "failed": true}


func _gag_labels(probe: Minigame) -> Array[Node]:
	return probe.find_children("*", "Label", true, false)


func test_start_with_a_time_limit_starts_the_countdown() -> void:
	var probe := _probe()
	probe._start({"time_limit": 5.0})
	assert_true(probe.is_running())
	assert_eq(probe.time_left(), 5.0)
	assert_eq(probe.time_fraction(), 1.0)
	assert_true(probe.has_countdown())


func test_start_without_a_time_limit_runs_untimed() -> void:
	var probe := _probe()
	probe._start({"time_limit": 0.0})
	assert_true(probe.is_running())
	assert_false(probe.has_countdown())
	var bare := _probe()
	bare._start()
	assert_false(bare.has_countdown(), "the zero-arg start stays untimed")


func test_a_countdown_that_ran_out_reads_as_no_countdown() -> void:
	var probe := _probe()
	probe._start({"time_limit": 0.05})
	await wait_seconds(0.3)
	assert_eq(probe.timeouts, 1, "the base timeout still fires")
	assert_false(probe.has_countdown())


func test_the_default_timeout_ends_nothing() -> void:
	var plain := Minigame.new()
	add_child_autofree(plain)
	watch_signals(plain)
	plain._start({"time_limit": 0.05})
	await wait_seconds(0.3)
	assert_signal_not_emitted(plain, "finished", "each game picks its own timeout rule")
	assert_true(plain.is_running())


func test_fail_plays_the_gag_before_reporting_a_failed_zero() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	probe._fail("💥")
	assert_signal_not_emitted(probe, "finished", "the gag plays first")
	assert_false(probe.is_running(), "input goes dead the moment the game is lost")
	var labels := _gag_labels(probe)
	assert_eq(labels.size(), 1)
	assert_eq((labels[0] as Label).text, "💥")
	await wait_seconds(0.3)
	assert_signal_emit_count(probe, "finished", 1)
	assert_eq(get_signal_parameters(probe, "finished"), [FAILED])


func test_fail_extras_merge_over_the_failed_result() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	probe._fail("🥚", {"score": 0.2, "choice": "burnt"})
	await wait_seconds(0.3)
	assert_eq(
		get_signal_parameters(probe, "finished"),
		[{"score": 0.2, "skipped": false, "failed": true, "choice": "burnt"}],
	)


func test_fail_stops_the_countdown_at_once() -> void:
	var probe := _probe()
	probe._start({"time_limit": 0.1, "fail_gag_seconds": 0.05})
	probe._fail("💥")
	await wait_seconds(0.3)
	assert_eq(probe.timeouts, 0, "a lost game never also times out")


func test_finish_skip_and_fail_during_the_gag_are_ignored() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	probe._fail("💥")
	probe._finish(1.0)
	probe._finish_with({"choice": "cook"})
	probe._on_skip_pressed()
	probe._fail("🔥")
	assert_signal_not_emitted(probe, "finished")
	assert_eq(_gag_labels(probe).size(), 1, "one gag, never two")
	await wait_seconds(0.3)
	assert_signal_emit_count(probe, "finished", 1)
	assert_eq(get_signal_parameters(probe, "finished"), [FAILED])


func test_fail_after_a_finish_reports_nothing_more() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	probe._finish(0.7)
	probe._fail("💥")
	await wait_seconds(0.3)
	assert_signal_emit_count(probe, "finished", 1)
	assert_eq(_gag_labels(probe).size(), 0, "a finished game shows no gag")


func test_the_gag_ticks_while_the_subclass_has_its_own_process() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	probe._fail("💥")
	await wait_seconds(0.3)
	assert_gt(probe.frames, 0, "precondition: the subclass _process ran")
	assert_signal_emit_count(probe, "finished", 1)


func test_the_gag_falls_back_to_the_balance_default() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(Minigame.DEFAULT_FAIL_GAG_SECONDS, cfg.fail_gag_seconds)
	assert_between(cfg.fail_gag_seconds, 1.0, 2.0, "the gag is a beat, not a scene")


func test_a_lost_game_is_gagging_until_it_reports() -> void:
	var probe := _probe()
	probe._start(QUICK_GAG)
	assert_false(probe.is_gagging(), "a live game is not gagging")
	probe._fail("💥")
	assert_true(probe.is_gagging(), "the gag is up")
	await wait_seconds(0.3)
	assert_false(probe.is_gagging(), "the gag is over once the result reports")


func test_a_finished_game_never_gags() -> void:
	var probe := _probe()
	probe._finish(1.0)
	assert_false(probe.is_gagging())
