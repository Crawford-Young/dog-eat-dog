extends GutTest

## TriageSession: work PM's inbox triage (issue #18). Emails pile into an inbox
## at a ramped rate; the oldest is on top, comes into focus over the read
## delay, and is sorted reply (A) or trash (D) before its window runs out. A
## full inbox buries what lands on it. Score = correct sorts / emails shown
## (sorted, expired or buried).

const WINDOW := 2.0
const GAP := 0.5
## Roomy enough that no test buries an email unless it sets its own.
const ROOMY := 100


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _session(
		read_delay := 0.0, speed := 1.0, seed_value := 7, jitter := 0.0, capacity := ROOMY,
		window := WINDOW
) -> TriageSession:
	return TriageSession.new({
		"window": window, "gap": GAP, "read_delay": read_delay, "speed": speed,
		"jitter": jitter, "capacity": capacity,
	}, _rng(seed_value))


func _sort_right(s: TriageSession) -> int:
	return s.sort(TriageSession.is_work(s.front_icon()))


func _sort_wrong(s: TriageSession) -> int:
	return s.sort(not TriageSession.is_work(s.front_icon()))


func test_a_fresh_inbox_holds_one_email_with_nothing_scored() -> void:
	var s := _session()
	assert_eq(s.inbox_size(), 1, "the first email is waiting from the start")
	assert_between(s.front_icon(), 0, TriageSession.ICON_COUNT - 1)
	assert_eq(s.correct, 0)
	assert_eq(s.wrong, 0)
	assert_eq(s.expired, 0)
	assert_eq(s.buried, 0)
	assert_eq(s.emails_shown(), 0, "the email on top is not resolved yet")


func test_the_first_three_icons_are_work_and_the_rest_junk() -> void:
	for icon in TriageSession.ICON_COUNT:
		assert_eq(TriageSession.is_work(icon), icon < TriageSession.WORK_ICONS, "icon %d" % icon)
	assert_eq(TriageSession.WORK_ICONS * 2, TriageSession.ICON_COUNT, "3 work, 3 junk")


func test_the_right_sort_scores_and_clears_the_email() -> void:
	var s := _session()
	assert_eq(_sort_right(s), TriageSession.CORRECT)
	assert_eq(s.correct, 1)
	assert_eq(s.inbox_size(), 0)
	assert_eq(s.emails_shown(), 1)


func test_the_wrong_sort_clears_the_email_as_not_correct() -> void:
	var s := _session()
	assert_eq(_sort_wrong(s), TriageSession.WRONG)
	assert_eq(s.wrong, 1)
	assert_eq(s.correct, 0)
	assert_eq(s.inbox_size(), 0, "a wrong sort still files the email")
	assert_eq(s.emails_shown(), 1)


func test_reply_is_right_for_work_and_trash_for_junk() -> void:
	var seen := {}
	for seed_value in 40:
		var s := _session(0.0, 1.0, seed_value)
		var work := TriageSession.is_work(s.front_icon())
		seen[work] = true
		assert_eq(s.sort(work), TriageSession.CORRECT)
	assert_eq(seen.size(), 2, "both kinds of email turn up")


func test_a_sort_on_an_empty_inbox_is_ignored() -> void:
	var s := _session()
	_sort_right(s)
	assert_eq(s.sort(true), TriageSession.IGNORED)
	assert_eq(s.sort(false), TriageSession.IGNORED)
	assert_eq(s.emails_shown(), 1, "nothing to file, nothing scored")
	assert_eq(s.front_icon(), -1, "no email on top")


func test_emails_arrive_every_gap() -> void:
	var s := _session()
	s.tick(GAP * 0.5)
	assert_eq(s.inbox_size(), 1)
	s.tick(GAP * 0.5)
	assert_eq(s.inbox_size(), 2, "the next email lands exactly one gap in")
	s.tick(GAP * 2.0)
	assert_eq(s.inbox_size(), 4, "one long tick lands every email it covers")


func test_the_oldest_email_is_on_top() -> void:
	var s := _session()
	var first := s.front_id()
	s.tick(GAP)
	assert_eq(s.front_id(), first, "a new arrival queues behind")
	assert_eq(s.icons().size(), 2)
	assert_eq(s.icons()[0], s.front_icon(), "icons() lists top first")
	_sort_right(s)
	assert_gt(s.front_id(), first, "the next email moves up")


func test_an_email_left_past_its_window_expires_as_not_correct() -> void:
	var s := _session()
	s.tick(GAP * 0.5)
	s.tick(WINDOW - GAP * 0.5)
	assert_eq(s.expired, 1, "the first email expires exactly when its window is used up")
	assert_eq(s.emails_shown(), 1)
	assert_almost_eq(s.score(), 0.0, 0.0001)


func test_the_window_counts_from_reaching_the_top() -> void:
	var s := _session()
	s.tick(GAP)  # a second email lands and waits
	s.tick(WINDOW - GAP)  # the first one expires
	assert_eq(s.expired, 1)
	assert_almost_eq(s.front_time_left(), WINDOW, 0.0001,
			"the second gets its whole window on top, however long it waited")
	assert_almost_eq(s.front_fraction(), 1.0, 0.0001)
	s.tick(GAP)
	assert_almost_eq(s.front_fraction(), (WINDOW - GAP) / WINDOW, 0.0001)


func test_a_sort_gives_the_next_email_its_whole_window() -> void:
	var s := _session()
	s.tick(GAP)
	s.tick(GAP)
	_sort_right(s)
	assert_almost_eq(s.front_time_left(), WINDOW, 0.0001)


func test_an_email_landing_in_an_empty_inbox_gets_its_whole_window() -> void:
	var s := _session()
	_sort_right(s)
	s.tick(GAP)
	assert_almost_eq(s.front_time_left(), WINDOW, 0.0001)


func test_a_full_inbox_buries_what_lands_on_it() -> void:
	var s := _session(0.0, 1.0, 7, 0.0, 3, 100.0)
	s.tick(GAP * 2.0)
	assert_eq(s.inbox_size(), 3, "precondition: full")
	assert_eq(s.buried, 0)
	s.tick(GAP * 2.0)
	assert_eq(s.buried, 2, "two more landed on a full inbox")
	assert_eq(s.inbox_size(), 3)
	assert_eq(s.emails_shown(), 2, "a buried email is shown and not correct")
	assert_almost_eq(s.score(), 0.0, 0.0001)
	_sort_right(s)
	s.tick(GAP)
	assert_eq(s.buried, 2, "a sort makes room for the next one")
	assert_eq(s.inbox_size(), 3)


func test_an_inbox_holds_at_least_the_email_on_top() -> void:
	var s := _session(0.0, 1.0, 7, 0.0, 0, 100.0)
	assert_eq(s.capacity(), 1)
	s.tick(GAP)
	assert_eq(s.inbox_size(), 1)
	assert_eq(s.buried, 1)


func test_an_empty_inbox_reports_no_window() -> void:
	var s := _session()
	_sort_right(s)
	assert_almost_eq(s.front_time_left(), 0.0, 0.0001)
	assert_almost_eq(s.front_fraction(), 0.0, 0.0001)


func test_play_speed_shrinks_the_window_and_the_gap() -> void:
	var s := _session(0.0, 2.0)
	assert_almost_eq(s.window(), WINDOW / 2.0, 0.0001)
	assert_almost_eq(s.gap(), GAP / 2.0, 0.0001)
	s.tick(GAP / 2.0)
	assert_eq(s.inbox_size(), 2, "mail lands twice as often")


func test_play_speed_has_a_floor() -> void:
	var s := _session(0.0, 0.0)
	assert_almost_eq(s.window(), WINDOW / TriageSession.MIN_SPEED, 0.0001,
			"a zero speed is the slowest inbox, not a divide by zero")


func test_the_window_and_gap_never_drop_under_their_floors() -> void:
	var s := TriageSession.new({"window": 0.0, "gap": 0.0, "read_delay": 0.0}, _rng())
	assert_almost_eq(s.window(), TriageSession.MIN_WINDOW, 0.0001)
	assert_almost_eq(s.gap(), TriageSession.MIN_GAP, 0.0001, "a zero gap would stall tick()")
	s.tick(1.0)
	assert_gt(s.expired, 0, "time still moves the inbox")


func test_the_top_email_is_out_of_focus_for_the_read_delay() -> void:
	var s := _session(0.25)
	assert_false(s.is_legible())
	assert_almost_eq(s.focus_fraction(), 0.0, 0.0001)
	assert_eq(_sort_right(s), TriageSession.IGNORED, "a sort before the subject reads is dropped")
	assert_eq(s.emails_shown(), 0)
	s.tick(0.125)
	assert_almost_eq(s.focus_fraction(), 0.5, 0.0001)
	s.tick(0.125)
	assert_true(s.is_legible())
	assert_eq(_sort_right(s), TriageSession.CORRECT)


func test_each_email_reaching_the_top_comes_into_focus_afresh() -> void:
	var s := _session(0.25)
	s.tick(GAP)
	_sort_right(s)
	assert_false(s.is_legible(), "the next email starts blurred")
	s.tick(0.25)
	assert_true(s.is_legible())


func test_an_email_landing_in_an_empty_inbox_starts_blurred() -> void:
	var s := _session(0.25)
	s.tick(0.25)
	_sort_right(s)
	s.tick(GAP - 0.25)
	assert_eq(s.inbox_size(), 1)
	assert_false(s.is_legible())


func test_an_expiry_brings_the_next_email_up_blurred() -> void:
	var s := _session(0.3)
	s.tick(GAP)
	s.tick(WINDOW - GAP)
	assert_eq(s.expired, 1)
	assert_false(s.is_legible())


func test_a_zero_read_delay_is_legible_at_once() -> void:
	var s := _session(0.0)
	assert_true(s.is_legible())
	assert_almost_eq(s.focus_fraction(), 1.0, 0.0001)


func test_an_empty_inbox_reads_as_out_of_focus() -> void:
	var s := _session(0.0)
	_sort_right(s)
	assert_false(s.is_legible(), "nothing on top to read")


func test_the_read_delay_ignores_play_speed() -> void:
	var s := _session(0.3, 3.0)
	s.tick(0.1)
	assert_false(s.is_legible(), "the dog's eyes do not speed up with the day")


func test_jitter_spreads_the_gaps_around_the_mean() -> void:
	var s := _session(0.0, 1.0, 3, 0.5)
	var gaps := []
	var last := 0.0
	var t := 0.0
	var size := s.inbox_size()
	for i in 4000:
		if gaps.size() >= 40:
			break
		s.tick(0.01)
		t += 0.01
		if s.inbox_size() > size:
			gaps.append(t - last)
			last = t
		while s.inbox_size() > 0:
			_sort_right(s)
		size = s.inbox_size()
	assert_eq(gaps.size(), 40, "40 arrivals inside 40 s")
	var lo := 100.0
	var hi := 0.0
	for g in gaps:
		lo = minf(lo, g)
		hi = maxf(hi, g)
	assert_gt(lo, GAP * 0.5 - 0.02, "no gap under (1 - jitter) of the mean")
	assert_lt(hi, GAP * 1.5 + 0.02, "no gap over (1 + jitter) of the mean")
	assert_gt(hi - lo, GAP * 0.3, "the gaps vary")


func test_score_is_correct_over_shown() -> void:
	var s := _session()
	_sort_right(s)
	s.tick(GAP)
	_sort_right(s)
	s.tick(GAP)
	_sort_wrong(s)
	s.tick(GAP)
	s.tick(WINDOW)  # the fourth expires
	assert_eq(s.emails_shown(), 4)
	assert_almost_eq(s.score(), 0.5, 0.0001)


func test_score_ignores_the_email_still_on_top() -> void:
	var s := _session()
	_sort_right(s)
	s.tick(GAP)
	assert_almost_eq(s.score(), 1.0, 0.0001, "the waiting email had no full window")


func test_nothing_shown_scores_zero() -> void:
	assert_almost_eq(_session().score(), 0.0, 0.0001)


func test_the_same_seed_fills_the_same_inbox() -> void:
	var a := _session(0.0, 1.0, 11, 0.5)
	var b := _session(0.0, 1.0, 11, 0.5)
	for i in 20:
		a.tick(0.13)
		b.tick(0.13)
		assert_eq(a.icons(), b.icons())


# --- the clarity tier must matter, and never in the dog's favour ------------


## Plays a whole shift as an actor who takes `react` seconds to act on each
## email once it reads, and always sorts right. Returns the shift's score.
func _play(params: Dictionary, react: float, seed_value: int) -> float:
	var s := TriageSession.new(params, _rng(seed_value))
	var step := 1.0 / 60.0
	var seen := -1
	var waited := 0.0
	var t := 0.0
	while t < params.shift_time:
		s.tick(step)
		t += step
		if s.front_id() != seen:
			seen = s.front_id()
			waited = 0.0
		if s.is_legible():
			waited += step
			if waited >= react:
				_sort_right(s)
	return s.score()


## A blurrier dog reads every email later, so at any reaction speed a lower
## tier never scores higher — the energy and snack levers cannot read
## inverted (the burst shipped that way once). Pinned on the shipped config
## for a fast and a slow actor at every rank.
func test_a_lower_tier_never_scores_higher_for_a_fast_or_a_slow_actor() -> void:
	var cfg := BalanceConfig.new()
	var actors := {"fast": 0.25, "slow": 0.6}
	for rank in cfg.triage_email_windows.size():
		for actor in actors:
			var previous := 1.0
			var top := 0.0
			for tier in [4, 3, 2, 1, 0]:
				var energy: float = [10.0, 30.0, 50.0, 70.0, 90.0][tier]
				var params := Difficulty.triage_params(energy, cfg, 0, rank)
				var total := 0.0
				for seed_value in 4:
					total += _play(params, actors[actor], seed_value)
				var score := total / 4.0
				if tier == 4:
					top = score
				assert_true(score <= previous + 0.0001,
						"%s actor, rank %d: tier %d scores %.3f, above %.3f" % [
							actor, rank, tier, score, previous])
				previous = score
			if actor == "slow":
				assert_lt(previous, top - 0.05,
						"rank %d: the bottom tier costs a slow actor real score" % rank)
