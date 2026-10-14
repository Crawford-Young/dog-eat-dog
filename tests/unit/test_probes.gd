extends GutTest

## The play probes (#18 step 12): every finished game appends one JSON line to
## a file and prints it, so a ride leaves a record of how hard each game was
## for the human. The recorder is driven against a temp path here; the game
## never writes under headless, so GUT and autoplay leave no file behind.

const TMP := "user://test_probes.jsonl"
const PREFIX := "[probe] "
const BREAKFAST := "res://scenes/minigames/breakfast.tscn"


func before_each() -> void:
	_remove_tmp()


func after_each() -> void:
	_remove_tmp()


func _remove_tmp() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


## Every line the temp file holds, parsed.
func _lines() -> Array:
	var out := []
	if not FileAccess.file_exists(TMP):
		return out
	for line in FileAccess.get_file_as_string(TMP).split("\n", false):
		out.append(JSON.parse_string(line))
	return out


## main.tscn with a recorder on the temp path, injected before _ready so the
## headless gate never gets a say. No stamp hold, so a finish advances at once.
func _main(start_from := "") -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.cfg = main.cfg.duplicate()
	main.cfg.stamp_hold_seconds = 0.0
	main.probes = ProbeLog.new("run-t", TMP)
	main.start_from_slot = start_from
	add_child_autofree(main)
	return main


## Last child: a finished game is queue_freed, so it lingers at the front.
func _hosted(main: Control) -> Minigame:
	var host: Control = main.get_node("%MinigameHost")
	return host.get_child(host.get_child_count() - 1)


# --- the recorder -----------------------------------------------------------


func test_probes_write_only_when_enabled_and_never_headless() -> void:
	assert_true(ProbeLog.should_write(true, "Windows"))
	assert_false(ProbeLog.should_write(false, "Windows"), "the config switch")
	assert_false(ProbeLog.should_write(true, "headless"), "GUT, autoplay and the CI launch")


func test_the_shipped_config_turns_probes_on() -> void:
	assert_true(BalanceConfig.new().probes_enabled)


func test_each_record_appends_one_json_line_tagged_with_the_run() -> void:
	var probes := ProbeLog.new("run-a", TMP)
	probes.record({"slot": "brush", "score": 1.0})
	probes.record({"slot": "shower", "score": 0.5})
	var lines := _lines()
	assert_eq(lines.size(), 2)
	assert_eq(lines[0].run, "run-a")
	assert_eq(lines[0].slot, "brush")
	assert_eq(lines[1].run, "run-a")
	assert_almost_eq(lines[1].score, 0.5, 0.0001)


func test_a_new_recorder_appends_rather_than_truncating() -> void:
	ProbeLog.new("run-a", TMP).record({"slot": "wake"})
	ProbeLog.new("run-b", TMP).record({"slot": "brush"})
	var lines := _lines()
	assert_eq(lines.size(), 2, "a ride across launches keeps every line")
	assert_eq(lines[1].run, "run-b")


func test_record_returns_the_prefixed_console_line() -> void:
	var line := ProbeLog.new("run-a", TMP).record({"slot": "wake"})
	assert_true(line.begins_with(PREFIX), line)
	assert_eq(JSON.parse_string(line.trim_prefix(PREFIX)).slot, "wake")


func test_a_run_id_is_not_empty() -> void:
	assert_ne(ProbeLog.new_run_id(), "")


# --- the hook at slot end ---------------------------------------------------


func test_a_finished_game_writes_one_probe_with_its_start_state() -> void:
	var main := _main()
	assert_eq(main.schedule.current(), "wake", "day 1 opens on the alarm")
	var energy: float = main.state.energy
	var limit: float = Difficulty.wake_params(energy, main.cfg).time_limit
	_hosted(main).finished.emit({"score": 0.75, "skipped": false, "failed": false})
	var lines := _lines()
	assert_eq(lines.size(), 1)
	var p: Dictionary = lines[0]
	assert_eq(p.run, "run-t")
	assert_eq(p.day, 1.0)
	assert_eq(p.slot, "wake")
	assert_almost_eq(p.score, 0.75, 0.0001)
	assert_eq(p.failed, false)
	assert_eq(p.skipped, false)
	assert_eq(p.choice, null, "a game with no choice reports none")
	assert_almost_eq(p.start_energy, energy, 0.001)
	assert_eq(p.rank, float(main.state.rank))
	assert_almost_eq(p.day_progress, 0.0, 0.0001)
	assert_almost_eq(p.ramp, 1.0, 0.0001, "wake has no day ramp")
	assert_almost_eq(p.time_limit, limit, 0.001)
	assert_almost_eq(p.clock_minute, float(main.cfg.morning_start_minutes), 0.01,
			"no frame ran, so the clock still reads the morning's start")
	assert_gte(p.seconds, 0.0)
	assert_eq(p.detail, {}, "a game with no detail hook reports an empty one")


func test_the_probe_carries_the_stamped_miss_and_the_choice() -> void:
	var main := _main("coffee")
	_hosted(main).finished.emit({"score": 0.0, "skipped": false, "failed": true, "choice": "spill"})
	var p: Dictionary = _lines()[0]
	assert_eq(p.slot, "coffee")
	assert_eq(p.failed, true)
	assert_eq(p.choice, "spill")
	assert_eq(p.clock_minute, null, "the office runs no clock")
	assert_gt(p.day_progress, 0.0)
	assert_almost_eq(p.ramp, Difficulty.day_ramp(p.day_progress, main.cfg.day_ramp_cup_max), 0.0001,
			"the cup rides its own day ramp")
	assert_true(p.detail.has("outcome"), "the cup's own detail rides along")


func test_a_shift_game_reports_its_shift_as_the_time_limit() -> void:
	var main := _main("work_am")
	_hosted(main).finished.emit({"score": 1.0, "skipped": false, "failed": false})
	var p: Dictionary = _lines()[0]
	assert_almost_eq(p.time_limit, main.cfg.burst_shift_time, 0.0001)
	assert_eq(p.detail.words, [], "nothing typed, nothing resolved")


func test_a_beat_that_is_not_a_game_writes_no_probe() -> void:
	var main := _main("sleep")
	_hosted(main).finished.emit({"score": 1.0, "skipped": false})
	assert_eq(_lines().size(), 0)


func test_the_config_switch_silences_an_attached_recorder() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.cfg = main.cfg.duplicate()
	main.cfg.stamp_hold_seconds = 0.0
	main.cfg.probes_enabled = false
	main.probes = ProbeLog.new("run-t", TMP)
	add_child_autofree(main)
	_hosted(main).finished.emit({"score": 1.0, "skipped": false, "failed": false})
	assert_eq(_lines().size(), 0)


func test_restarting_starts_a_new_run() -> void:
	var main := _main()
	main._on_restart_pressed()
	_hosted(main).finished.emit({"score": 1.0, "skipped": false, "failed": false})
	assert_ne(_lines()[0].run, "run-t")


# --- per-game detail --------------------------------------------------------


func test_the_base_minigame_has_no_detail() -> void:
	assert_eq(autofree(Minigame.new()).probe_detail(), {})


func test_burst_times_each_resolved_word_against_its_window() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := BurstSession.new(4, 4.0, 2.0, rng)
	s.tick(0.5)
	for c in s.remaining():
		s.input_char(c)
	assert_false(s.input_char("#"), "a typo")
	s.tick(2.5)
	var d := s.probe_detail()
	assert_eq(d.typos, 1)
	assert_eq(d.words.size(), 2, "the typed word and the expired one; not the one on screen")
	assert_almost_eq(d.words[0].window, 2.0, 0.0001, "the window over play speed")
	assert_almost_eq(d.words[0].seconds, 0.5, 0.0001)
	assert_almost_eq(d.words[1].window, 2.0, 0.0001)
	assert_eq(d.words[1].seconds, null, "an expired word was never typed")


func test_triage_reports_each_resolved_email_right_or_not_and_how_fast() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := TriageSession.new(
		{"window": 3.0, "gap": 10.0, "read_delay": 0.2, "capacity": 100}, rng
	)
	s.tick(1.0)
	s.sort(TriageSession.is_work(s.front_icon()))
	s.tick(9.0)
	s.tick(3.0)
	s.tick(7.0)
	s.tick(0.5)
	s.sort(not TriageSession.is_work(s.front_icon()))
	var emails: Array = s.probe_detail().emails
	assert_eq(emails.size(), 3)
	assert_eq(emails[0].correct, true)
	assert_almost_eq(emails[0].seconds, 1.0, 0.0001, "from reaching the top to sorted")
	assert_eq(emails[1].correct, false)
	assert_eq(emails[1].seconds, null, "expired on top")
	assert_eq(emails[2].correct, false, "sorted the wrong way")
	assert_almost_eq(emails[2].seconds, 0.5, 0.0001)


func test_triage_reports_a_buried_email_as_never_reaching_the_top() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := TriageSession.new(
		{"window": 100.0, "gap": 1.0, "read_delay": 0.0, "capacity": 1}, rng
	)
	s.tick(1.0)
	assert_eq(s.probe_detail().emails, [{"correct": false, "seconds": null}])


func test_the_cup_reports_its_press_offset_from_the_zone_centre() -> void:
	var s := CoffeeSession.new({"speed": 1.0, "zone_center": 0.5, "zone_width": 0.2, "lead": 0.0})
	s.tick(0.45)
	s.grab()
	var d := s.probe_detail()
	assert_eq(d.outcome, CoffeeSession.BUY)
	assert_almost_eq(d.offset, -0.05, 0.0001, "pressed a touch early")
	assert_almost_eq(d.half_zone, 0.1, 0.0001)
	assert_eq(d.can_afford, true)


func test_a_cup_left_to_pass_has_no_offset() -> void:
	var s := CoffeeSession.new({
		"speed": 1.0, "zone_center": 0.5, "zone_width": 0.2, "lead": 0.0, "can_afford": false,
	})
	s.grab()
	s.tick(2.0)
	var d := s.probe_detail()
	assert_eq(d.outcome, CoffeeSession.SKIP)
	assert_eq(d.offset, null)
	assert_eq(d.can_afford, false, "broke, so the press did nothing")


func test_breakfast_reports_each_beats_offset_from_the_centre() -> void:
	var node: Minigame = load(BREAKFAST).instantiate()
	add_child_autofree(node)
	node.setup({"window": 0.3, "speed": 1.6, "beats": 3, "time_limit": 100.0})
	for at in [0.5, 0.6, 0.1]:
		node._beat.position = at
		node._press()
	var d := node.probe_detail()
	assert_eq(d.offsets.size(), 3)
	assert_almost_eq(d.offsets[0], 0.0, 0.0001)
	assert_almost_eq(d.offsets[1], 0.1, 0.0001)
	assert_almost_eq(d.offsets[2], -0.4, 0.0001)
	assert_almost_eq(d.half_window, 0.15, 0.0001)
