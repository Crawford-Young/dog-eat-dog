extends GutTest

## Scene-level smoke: walk main.tscn through every slot of a day by faking each
## minigame's finished signal. Catches host wiring, per-slot params and the
## summary hand-off — not per-minigame behaviour, which its own suite covers.
##
## Wave 2: the day list is built fresh every morning (sick short-circuit, retire
## offer, warning beat, coffee cart), so every walk drives
## DaySchedule.build(state, cfg) — never a fixed slot list.
##
## Wave 3a: the morning is a triage run against a draining clock (shower,
## clothes, breakfast, drive). The clock only moves in _process and in the fixed
## skip costs, and a synchronous walk ticks no frames — so clock tests drive
## main._process(delta) by hand or spend on main.clock directly.

const FAKE_RESULTS := {
	"coffee": {"score": 1.0, "skipped": false, "choice": "skip"},
	"dinner": {"score": 1.0, "skipped": false, "choice": "cook"},
	"freetime": {"score": 0.33, "skipped": false, "choice": "logoff", "games_played": 2},
	"retire_offer": {"score": 1.0, "skipped": false, "choice": "stay"},
}
const BUY_COFFEE := {"score": 1.0, "skipped": false, "choice": "buy"}
const SPILL_COFFEE := {"score": 0.0, "skipped": false, "failed": true, "choice": "spill"}
const RETIRE := {"score": 1.0, "skipped": false, "choice": "retire"}
const BAD_WORK := {"score": 0.0, "skipped": false}
const SKIPPED := {"score": 0.0, "skipped": true}
const DONE := {"score": 1.0, "skipped": false}


## Last child, NOT child 0: game.gd queue_free()s the outgoing minigame, and
## queue_free defers the actual removal past the end of this synchronous loop,
## so finished slots pile up at the front of the host. Do not "simplify" this
## to get_child(0) — it would hand back an already-freed minigame.
func _current_minigame(host: Control) -> Minigame:
	return host.get_child(host.get_child_count() - 1)


## The verdict stamp holds the next slot back for stamp_hold_seconds of real
## frames, and a synchronous walk ticks none, so walks run with no hold by
## default. The hold's own tests pass the shipped length.
func _fresh_main(stamp_hold := 0.0) -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.cfg = main.cfg.duplicate()
	main.cfg.stamp_hold_seconds = stamp_hold
	add_child_autofree(main)
	return main


func _held_main() -> Control:
	return _fresh_main(BalanceConfig.new().stamp_hold_seconds)


## The morning rebuild game.gd runs at _ready and at next-day, for tests that
## seed state after instantiation. The day-1 minigame already hosted is left
## behind un-driven — _current_minigame always walks from the back.
func _reseed(main: Control) -> void:
	main.schedule.set_slots(DaySchedule.build(main.state, main.cfg))
	main._start_slot()


func _result_for(slot: String, overrides: Dictionary) -> Dictionary:
	# .duplicate() is load-bearing because T5 stamps onto the freetime result
	# in place (game.gd's "band"/"bed_minute" write): FAKE_RESULTS is a const,
	# and GDScript freezes const dictionary VALUES read-only too, so handing
	# back the frozen entry directly makes game.gd's write fail.
	return overrides.get(slot, FAKE_RESULTS.get(slot, {"score": 1.0, "skipped": false})).duplicate()


## Drive the day game.gd actually built, one faked finish per slot. Stops after
## `until` when given one, so a test can read mid-day state.
func _walk(main: Control, overrides: Dictionary = {}, until: String = "") -> void:
	var host: Control = main.get_node("%MinigameHost")
	for slot in DaySchedule.build(main.state, main.cfg):
		var node := _current_minigame(host)
		assert_not_null(node, "a minigame is hosted for slot %s" % slot)
		node.finished.emit(_result_for(slot, overrides))
		if slot == until:
			return
		if slot == "work_pm":
			_finish_rank_news_beat_if_pending(main, host)
		if slot == "dinner":
			_finish_cooking_beat_if_pending(main, host)


## QA ruling (issue #10 / finding 1): promotion/demotion/warning news is a
## same-day office beat hosted right after work_pm, OUTSIDE the normal slot
## schedule — schedule.current() stays "work_pm" (advance() never ran) while
## it's up. Drive it like any other beat before the walk moves on, unless the
## caller stopped exactly at "work_pm" to inspect the pending beat itself.
func _finish_rank_news_beat_if_pending(main: Control, host: Control) -> void:
	if main.schedule.current() != "work_pm":
		return
	_current_minigame(host).finished.emit({"score": 1.0, "skipped": false})


## Same shape as the rank-news helper: T8's cooking pan is out-of-band the same
## way, so schedule.current() stays "dinner" (advance() never ran) while the
## pan is up. A no-op for takeout — that branch advances the schedule itself,
## so current() has already moved past "dinner" by the time this checks.
func _finish_cooking_beat_if_pending(main: Control, host: Control) -> void:
	if main.schedule.current() != "dinner":
		return
	_current_minigame(host).finished.emit({"score": 1.0, "skipped": false})


## Summary and ending copy type themselves out, so the label is still empty on
## the frame they start — skip() flushes the whole line synchronously.
func _summary_text(main: Control) -> String:
	main._summary_typer.skip()
	return (main.get_node("%SummaryLabel") as Label).text


func _ending_text(main: Control) -> String:
	main._ending_typer.skip()
	return (main.get_node("%EndingLabel") as Label).text


func test_a_whole_day_runs_through_to_the_summary() -> void:
	var main := _fresh_main()
	_walk(main)
	var summary: Panel = main.get_node("%Summary")
	assert_true(summary.visible, "the day ends on the summary panel")


func test_a_full_day_pays_the_days_salary() -> void:
	# QA ruling (issue #8): close_day nets the margin over living costs, not
	# the raw salary. This fixed walk buys no coffee/takeout (coffee "skip",
	# dinner "cook"), so the only drain past the paycheque is the daily
	# living cost.
	var main := _fresh_main()
	_walk(main)
	assert_eq(
		main.state.wallet.savings,
		main.cfg.salaries[0] - main.cfg.daily_living_cost,
		"the mailroom salary, minus the day's living cost, lands at close",
	)
	assert_string_contains(_summary_text(main), "paid %d bone-bucks" % main.cfg.salaries[0])
	assert_string_contains(
		_summary_text(main), "rent and kibble took %d" % main.cfg.daily_living_cost
	)


## #11 "HUD layout": savings against the target is the score, top-right.
func test_the_poster_scores_savings_against_the_retirement_target() -> void:
	var main := _fresh_main()
	var poster: Label = main.get_node("%PosterLabel")
	assert_eq(poster.text, "🦴 0 / %d to retire" % main.cfg.retirement_target)
	_walk(main)
	var banked: int = main.cfg.salaries[0] - main.cfg.daily_living_cost
	assert_eq(
		poster.text,
		"🦴 %d / %d to retire" % [banked, main.cfg.retirement_target],
		"the day's pay shows on the summary, not only the next morning",
	)
	main._on_next_day_pressed()
	assert_eq(poster.text, "🦴 %d / %d to retire" % [banked, main.cfg.retirement_target])
	assert_true(poster.visible, "the score is always up")


func test_the_rank_stays_on_the_top_left() -> void:
	var main := _fresh_main()
	var rank: Label = main.get_node("%RankLabel")
	assert_eq(rank.text, "mailroom")
	main.state.rank = 2
	main._start_slot()
	assert_eq(rank.text, RankLadder.RANK_NAMES[2])


func test_coffee_buys_focus_now_and_pays_for_it_at_work() -> void:
	var buyer := _fresh_main()
	buyer.state.wallet.savings = 20
	_walk(buyer, {"coffee": BUY_COFFEE}, "work_am")
	var sober := _fresh_main()
	sober.state.wallet.savings = 20
	_walk(sober, {}, "work_am")
	assert_true(buyer.state.coffee_today, "buying the coffee marks the day")
	assert_eq(buyer.state.wallet.savings, 20 - buyer.cfg.coffee_price, "the cart takes its five")
	assert_almost_eq(
		buyer.state.energy,
		sober.state.energy - buyer.cfg.coffee_crash_drain,
		0.001,
		"the crash lands on the morning work slot, not the afternoon",
	)


func test_both_day_end_panels_wrap_their_copy() -> void:
	var main := _fresh_main()
	assert_ne(
		(main.get_node("%SummaryLabel") as Label).autowrap_mode,
		TextServer.AUTOWRAP_OFF,
		"summary lines run long (the senior tease, the wobble warning) — wrap them",
	)
	assert_ne(
		(main.get_node("%EndingLabel") as Label).autowrap_mode,
		TextServer.AUTOWRAP_OFF,
		"the ending is three long lines in a small panel",
	)


func test_coffee_lifts_the_morning_burst_tier_only() -> void:
	# Energy is seeded low so the morning's shower + breakfast refills leave the
	# dog short of the top clarity tier — the coffee lift is only visible below
	# the cap (clarity_tier maxes out at 4).
	var buyer := _fresh_main()
	buyer.state.wallet.savings = 20
	buyer.state.energy = 30.0
	_walk(buyer, {"coffee": BUY_COFFEE}, "coffee")
	var sober := _fresh_main()
	sober.state.wallet.savings = 20
	sober.state.energy = 30.0
	_walk(sober, {}, "coffee")
	assert_eq(buyer.state.energy, sober.state.energy, "coffee costs money, not energy")
	var clear := Difficulty.clarity_tier(sober.state.energy)
	assert_eq(sober._params_for("work_am").tier, clear, "no coffee, no lift")
	assert_gt(buyer._params_for("work_am").tier, clear, "coffee lifts the morning burst tier")
	assert_eq(buyer._params_for("work_pm").tier, clear, "the buff is morning-only")


func test_a_sick_morning_is_one_unpaid_day_in_the_blanket() -> void:
	var main := _fresh_main()
	main.state.energy = 5.0
	main.state.promote_streak = 2
	_reseed(main)
	assert_eq(DaySchedule.build(main.state, main.cfg), ["sick"], "a wrecked morning is the whole day")
	_current_minigame(main.get_node("%MinigameHost")).finished.emit({"score": 1.0, "skipped": false})
	assert_true((main.get_node("%Summary") as Panel).visible, "the sick day still closes on a summary")
	assert_eq(main.state.wallet.savings, 0, "no work, no pay")
	assert_string_contains(_summary_text(main), "no pay today")
	assert_eq(main.state.rank, 0, "the ladder never ran")
	assert_false(main.state.warning, "a sick day is not a performance judgement")
	assert_eq(main.state.promote_streak, 2, "the streak waits out the blanket, it is not reset")
	main._on_next_day_pressed()
	assert_almost_eq(
		main.state.energy, main.cfg.sick_reset_max, 0.001, "a full burrow resets to the good end"
	)
	assert_eq(main.state.day, 2, "the blanket costs exactly one day")
	assert_eq(
		DaySchedule.build(main.state, main.cfg),
		["wake", "brush", "shower", "clothes", "breakfast", "drive", "coffee", "work_am",
				"lunch", "work_pm", "drive_home", "dinner", "freetime", "sleep"],
		"day two is an ordinary day again",
	)


func test_the_retire_offer_leads_the_day_and_ends_the_game() -> void:
	var main := _fresh_main()
	main.state.wallet.savings = main.cfg.retirement_target
	_reseed(main)
	var slots := DaySchedule.build(main.state, main.cfg)
	assert_eq(slots[0], "wake", "the dog still gets up first")
	assert_eq(slots[1], "retire_offer", "the offer is the next thing it hears")
	var host: Control = main.get_node("%MinigameHost")
	_current_minigame(host).finished.emit({"score": 1.0, "skipped": false})
	_current_minigame(host).finished.emit(RETIRE)
	assert_true((main.get_node("%Ending") as Panel).visible, "retiring ends the game")
	assert_false((main.get_node("%Summary") as Panel).visible, "no day summary after retiring")
	var ending := _ending_text(main)
	assert_string_contains(ending, "the poster comes off the wall.")
	assert_string_contains(ending, "mailroom, retired.")


func test_staying_one_more_day_keeps_the_day_running() -> void:
	var main := _fresh_main()
	main.state.wallet.savings = main.cfg.retirement_target
	_reseed(main)
	_walk(main)
	assert_false((main.get_node("%Ending") as Panel).visible, "staying is not an ending")
	assert_true((main.get_node("%Summary") as Panel).visible, "the day finishes as normal")
	assert_eq(
		main.state.wallet.savings,
		main.cfg.retirement_target + (main.cfg.salaries[0] - main.cfg.daily_living_cost),
		"one more day is one more paycheque, minus that day's living cost",
	)


func test_restarting_after_the_ending_starts_a_fresh_dog() -> void:
	var main := _fresh_main()
	main.state.wallet.savings = main.cfg.retirement_target
	_reseed(main)
	var host: Control = main.get_node("%MinigameHost")
	_current_minigame(host).finished.emit({"score": 1.0, "skipped": false})
	_current_minigame(host).finished.emit(RETIRE)
	main._on_restart_pressed()
	assert_false((main.get_node("%Ending") as Panel).visible, "the ending panel steps aside")
	assert_true(main._ending_typer.is_done(), "the ending stops typing into the hidden label")
	assert_eq(main.state.day, 1, "day one again")
	assert_eq(main.state.wallet.savings, 0, "the poster is blank again")
	assert_eq(main.schedule.current(), "wake", "a fresh morning is hosted")


func test_a_bad_day_earns_a_warning_the_cat_delivers_tomorrow() -> void:
	# QA ruling (issue #10 / finding 1): the "warned" news lands as a
	# same-day office beat right after work_pm, not in the day-end summary.
	var main := _fresh_main()
	_walk(main, {"work_am": BAD_WORK, "work_pm": BAD_WORK}, "work_pm")
	var host: Control = main.get_node("%MinigameHost")
	var beat := _current_minigame(host)
	beat._typer.skip()
	assert_string_contains(
		(beat.get_node("%Line") as Label).text,
		"the cat glanced at your screen today. twice.",
		"the office delivers the news same-day",
	)
	beat.finished.emit({"score": 1.0, "skipped": false})
	for slot in ["drive_home", "dinner", "freetime", "sleep"]:
		_current_minigame(host).finished.emit(_result_for(slot, {}))
		_finish_cooking_beat_if_pending(main, host)
	assert_false(
		_summary_text(main).contains("the cat glanced at your screen today. twice."),
		"rank news does not repeat in the day-end summary",
	)
	main._on_next_day_pressed()
	assert_true(
		DaySchedule.build(main.state, main.cfg).has("warning"),
		"the warning beat is on tomorrow's list",
	)


func test_a_sustained_promotion_announces_at_the_office_before_the_summary() -> void:
	# QA ruling (issue #10 / finding 1): rank news is a same-day office beat,
	# blocking the summary until it's dismissed.
	var main := _fresh_main()
	main.state.performance = 0.9
	main.state.promote_streak = main.cfg.promote_sustain_days - 1
	_reseed(main)
	_walk(main, {}, "work_pm")
	assert_eq(
		main.schedule.current(), "work_pm", "the office beat blocks advance() until it finishes"
	)
	var host: Control = main.get_node("%MinigameHost")
	var beat := _current_minigame(host)
	beat._typer.skip()
	assert_string_contains(
		(beat.get_node("%Line") as Label).text,
		"new desk. same dog, better title.",
		"the beat shows the promoted copy",
	)
	assert_false(
		(main.get_node("%Summary") as Panel).visible,
		"the summary must not appear while the office beat is still up",
	)
	beat.finished.emit({"score": 1.0, "skipped": false})
	assert_eq(main.state.rank, 1, "the promotion actually landed")
	for slot in ["drive_home", "dinner", "freetime", "sleep"]:
		_current_minigame(host).finished.emit(_result_for(slot, {}))
		_finish_cooking_beat_if_pending(main, host)
	assert_true(
		(main.get_node("%Summary") as Panel).visible, "the day still closes on a summary afterward"
	)


func test_the_summary_telegraphs_a_tomorrow_that_might_not_happen() -> void:
	# Wave-2 QA ruling (issue #5): next-day energy blends leftover energy
	# with the bedtime target (energy_carry_weight, default 0.5), so a wrecked
	# bedtime target alone does not guarantee a sick warning — it has to clear
	# the threshold together with whatever energy is left at day's end (44.0 for
	# this fixed walk, since the morning restores on shower and
	# breakfast: 0.5*44 + 0.5*wrecked < sick_energy_threshold).
	#
	# Wave 3b: bedtime comes from the evening clock's band, not the game count,
	# so a synchronous walk's band is not this test's business — every
	# band is wrecked, and the telegraph is what is under test either way.
	var main := _fresh_main()
	main.cfg.sleep_energy = {"early": -60.0, "mid": -60.0, "late": -60.0}
	_walk(main)
	assert_string_contains(_summary_text(main), "tomorrow might not happen")
	var rested := _fresh_main()
	_walk(rested)
	assert_false(
		_summary_text(rested).contains("tomorrow might not happen"),
		"a night that only ends tired says nothing",
	)


func test_the_tomorrow_projection_matches_what_the_next_day_actually_does() -> void:
	# The mirror invariant (repo CLAUDE.md), asserted against itself rather than
	# reviewed by eye. Nothing else in the suite catches a projection that is
	# merely WRONG: the wobble telegraph would warn on mornings the dog wakes
	# fine, or stay quiet on the morning it cannot get up, and every assertion
	# still passes. Both branches and both ends of the debt range, because the
	# sick branch returns through a clamp of its own.
	var main := _fresh_main()
	for sick in [false, true]:
		for debt in [0.0, main.cfg.sleep_debt_cap_minutes]:
			var s := GameState.new()
			s.bedtime = "late"
			s.energy = 40.0
			s.brushed_today = false
			s.showered_today = true
			s.sick_today = sick
			s.sick_recovery = 72.0
			s.ledger.debt_minutes = debt
			s.refresh_ceiling(main.cfg)
			main.state = s
			var projected: float = main._tomorrow_energy()
			s.start_next_day(main.cfg)
			assert_almost_eq(
				s.energy,
				projected,
				0.001,
				"projection drifted from the real morning at sick=%s debt=%s" % [sick, debt],
			)


func test_the_new_morning_slots_each_get_their_own_difficulty_params() -> void:
	var main := _fresh_main()
	assert_true(main._params_for("shower").has("spots"), "the shower reads its spot count")
	assert_true(main._params_for("clothes").has("fumble_chance"), "dressing reads its fumbles")
	assert_true(main._params_for("breakfast").has("beats"), "breakfast reads its beat count")
	assert_true(main._params_for("drive").has("car_count"), "the commute reads its traffic")


func test_both_work_shifts_read_the_dogs_rank() -> void:
	var main := _fresh_main()
	main.state.rank = 2
	assert_eq(main._params_for("work_am").window, main.cfg.burst_word_windows[2],
			"the burst's word window")
	assert_eq(main._params_for("work_pm").window, main.cfg.triage_email_windows[2],
			"the triage's email window")


func test_the_morning_budget_is_derived_from_the_arrival_deadline() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(cfg.work_start_minutes, 480, "work starts at 8:00")
	# Asserted as the RELATION, not as a literal. The deadline is the round's
	# primary feel lever and has moved three times (510 -> 525 -> 480); what must
	# never change is that the budget is derived from it rather than stored
	# beside it.
	assert_eq(cfg.morning_budget(), float(cfg.work_start_minutes - cfg.morning_start_minutes),
			"the morning is the gap to the deadline")
	assert_eq(cfg.morning_budget(), 45.0, "and that gap is currently 45 minutes (7:15 wake, #18)")
	assert_eq(_fresh_main().clock.budget, cfg.morning_budget(),
			"the clock is built from the derived budget, not a standalone tunable")


func test_the_evening_budget_is_derived_from_the_last_band_line() -> void:
	# Same rule as morning_budget: the LINE is the stored design intent and the
	# span is computed. A stored evening_budget_minutes would split the
	# authority, as with morning_budget.
	var cfg := BalanceConfig.new()
	assert_eq(
		cfg.evening_budget(),
		float(cfg.bed_mid_line_minutes - cfg.evening_start_minutes),
		"the evening's span is the gap between leaving the office and the last band",
	)


func test_the_band_lines_are_offsets_from_the_evenings_start() -> void:
	var cfg := BalanceConfig.new()
	var lines := cfg.bed_band_lines()
	assert_eq(lines.size(), 2, "three bands are cut by two lines")
	assert_eq(lines[0], float(cfg.bed_early_line_minutes - cfg.evening_start_minutes))
	assert_eq(lines[1], float(cfg.bed_mid_line_minutes - cfg.evening_start_minutes))
	assert_eq(lines[1], cfg.evening_budget(), "the last line IS the budget")


func test_the_drive_home_budget_is_derived_from_the_home_by_line() -> void:
	# Same rule as the morning: the line is stored (absolute, like 8:00) and the
	# span from leaving the office is computed.
	var cfg := BalanceConfig.new()
	assert_eq(cfg.home_budget(), float(cfg.home_by_minutes - cfg.evening_start_minutes))
	assert_gt(cfg.home_by_minutes, cfg.evening_start_minutes, "home_by is after leaving the office")
	assert_lt(cfg.home_by_minutes, cfg.bed_early_line_minutes,
			"and before the early bed line, which the drive home must not cost by itself")


func test_the_band_names_are_the_sleep_energy_keys() -> void:
	# One vocabulary for the bands. If these ever diverge, start_next_day
	# indexes sleep_energy with a key it does not have and the day crashes.
	var cfg := BalanceConfig.new()
	assert_eq(BalanceConfig.BANDS.size(), 3)
	for band in BalanceConfig.BANDS:
		assert_true(cfg.sleep_energy.has(band), "sleep_energy is missing the '%s' band" % band)


func test_a_maxed_debt_ceiling_can_reach_the_sick_cliff() -> void:
	# The whole point of the ceiling. Today sleep_energy["late"] is 35 and the
	# carry blend trends toward it, so a permanently-late dog never reaches the
	# threshold of 12 — chronic lateness is currently free.
	var cfg := BalanceConfig.new()
	assert_lt(
		cfg.sleep_ceiling_min,
		cfg.sick_energy_threshold,
		"a fully-indebted dog has to be ABLE to get sick or the mechanic is inert",
	)


func test_the_drive_home_is_shorter_than_the_morning_commute() -> void:
	# Wave-3b invariant, held as data. Two full commutes a day is the failure
	# mode this exists to prevent: the commute is the morning's biggest single
	# cost, and evening time belongs in cooking and freetime.
	var cfg := BalanceConfig.new()
	assert_lt(cfg.drive_home_length, cfg.drive_length)
	assert_lt(cfg.drive_home_route_miles, cfg.drive_route_miles)


func test_the_clock_hud_states_the_deadline_the_dog_is_racing() -> void:
	# The whole point of the round: an abstract budget becomes a stated time.
	var main := _fresh_main()
	var clock_label: Label = main.get_node("%ClockLabel")
	main._process(0.0)
	assert_string_contains(clock_label.text, "in by 8:00")


## The clock is the whole point of the morning and the commute is where it bites
## hardest — and the commute is also the ONLY slot that paints a full-height
## opaque road straight down the middle of the screen, through exactly the strip
## the clock sits in. Sibling draw order is the single thing keeping it visible;
## a wrong order hides the clock behind the road for the entire drive while the
## label still updates correctly, so only a draw-order check catches it.
func test_the_clock_draws_on_top_of_whatever_minigame_is_up() -> void:
	var main := _fresh_main()
	assert_gt(
		main.get_node("%ClockLabel").get_index(),
		main.get_node("%MinigameHost").get_index(),
		"the minigame host draws after the clock, so it paints over it"
	)


func test_the_clock_runs_through_the_morning_and_stops_at_the_office() -> void:
	# _process is the HUD's whole body and no engine frames tick inside a
	# synchronous walk, so drive it by hand.
	var main := _fresh_main()
	var clock_label: Label = main.get_node("%ClockLabel")
	main._process(0.0)
	assert_true(clock_label.visible, "the clock is up from the first morning slot")
	assert_string_contains(clock_label.text, main.clock.clock_text(main.cfg.morning_start_minutes))
	assert_eq(
		clock_label.get_theme_color("font_color"),
		main.ZONE_COLORS["calm"],
		"a fresh budget reads calm",
	)
	main.clock.spend(main.cfg.morning_budget())
	main._process(0.0)
	assert_eq(
		clock_label.get_theme_color("font_color"),
		main.ZONE_COLORS["red"],
		"a spent budget reads red",
	)
	_walk(main, {}, "drive")
	main._process(0.0)
	assert_false(clock_label.visible, "the clock is gone once the dog is at work")


func test_the_clock_burns_real_seconds_while_a_morning_slot_is_up() -> void:
	var main := _fresh_main()
	main._process(2.0)
	assert_almost_eq(main.clock.elapsed, 2.0 * main.cfg.clock_scale, 0.001)


func test_skipping_a_morning_chore_costs_clock_time() -> void:
	var skipper := _fresh_main()
	_walk(skipper, {"shower": SKIPPED}, "shower")
	var washer := _fresh_main()
	_walk(washer, {}, "shower")
	assert_almost_eq(
		skipper.clock.elapsed - washer.clock.elapsed,
		skipper.cfg.skip_time_cost,
		0.001,
		"ducking out of the shower buys back nothing — it burns the budget",
	)


func test_the_summary_notices_a_day_spent_unwashed() -> void:
	var skipper := _fresh_main()
	_walk(skipper, {"shower": SKIPPED})
	assert_string_contains(_summary_text(skipper), "the stink kept its own desk chair today")
	var washer := _fresh_main()
	_walk(washer)
	assert_false(
		_summary_text(washer).contains("stink"), "a washed dog gets no comment"
	)


## The late beat is hosted OUTSIDE the schedule, same shape as the rank news:
## advance() never runs for it, so schedule.current() stays "drive" while it is
## up. Its own finished signal resumes the day.
func test_arriving_late_slinks_in_and_debits_the_day() -> void:
	var main := _fresh_main()
	var host: Control = main.get_node("%MinigameHost")
	var clock_label: Label = main.get_node("%ClockLabel")
	var before: float = main.state.performance
	for slot in DaySchedule.build(main.state, main.cfg):
		if slot == "drive":
			main.clock.spend(999.0)
		_current_minigame(host).finished.emit(_result_for(slot, {}))
		if slot == "drive":
			assert_eq(main.schedule.current(), "drive", "the late beat blocks advance()")
			assert_almost_eq(
				main.state.performance,
				before - main.cfg.lateness_debit_cap,
				0.001,
				"a wildly late arrival takes the capped debit",
			)
			main._process(0.0)
			assert_false(clock_label.visible, "the clock stops once the overrun is banked")
			var beat := _current_minigame(host)
			beat._typer.skip()
			assert_string_contains((beat.get_node("%Line") as Label).text, "you slink in at ")
			beat.finished.emit(DONE)
		if slot == "work_pm":
			_finish_rank_news_beat_if_pending(main, host)
		if slot == "dinner":
			_finish_cooking_beat_if_pending(main, host)
	assert_true(
		(main.get_node("%Summary") as Panel).visible, "a late day still closes on a summary"
	)


func test_arriving_on_time_skips_the_late_beat_entirely() -> void:
	var main := _fresh_main()
	var host: Control = main.get_node("%MinigameHost")
	_walk(main, {}, "drive")
	assert_eq(main.schedule.current(), "coffee", "on time, the day just moves on")
	assert_almost_eq(main.state.performance, 0.5, 0.001, "no debit for a punctual dog")
	assert_eq(
		_current_minigame(host).scene_file_path,
		"res://scenes/minigames/coffee.tscn",
		"the coffee cart is hosted next, not a late beat",
	)


func test_the_evening_clock_runs_from_the_drive_home_to_bed() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["drive_home", "dinner", "freetime", "sleep"] as Array[String])
	main._start_slot()
	assert_eq(main.clock.budget, main.cfg.evening_budget(), "a fresh clock for the evening")
	assert_eq(main.clock.band_name(), "early", "which starts with every band still available")
	assert_true(main._clock_running)


func test_the_evening_clock_is_hidden_at_the_sleep_beat() -> void:
	# The night is already decided by the time the beat plays — letting the HUD
	# tick behind that copy would be a lie, same reasoning as the late beat.
	var main := _fresh_main()
	main.schedule.set_slots(["sleep"] as Array[String])
	main._start_slot()
	assert_false(main._clock_running)


func test_the_band_the_clock_lands_on_becomes_the_bedtime() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["drive_home", "dinner", "freetime", "sleep"] as Array[String])
	main._start_slot()
	main.clock.spend(main.cfg.evening_budget())
	main._on_finished(
		{"score": 1.0, "skipped": false, "games_played": 3}, "freetime", autofree(Node.new())
	)
	assert_eq(main.state.bedtime, "late", "a burned evening is a late night")
	assert_gt(main.state.ledger.debt_minutes, 0.0, "and a late night owes sleep")


func test_an_early_evening_banks_sleep() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["drive_home", "dinner", "freetime", "sleep"] as Array[String])
	main._start_slot()
	main._on_finished(
		{"score": 1.0, "skipped": false, "games_played": 0}, "freetime", autofree(Node.new())
	)
	assert_eq(main.state.bedtime, "early")
	assert_lt(main.state.ledger.debt_minutes, 0.0, "straight to bed banks the surplus")


## The integration the day-reaches-summary tests only imply: picking cook
## actually hosts the pan out-of-band, and finishing the pan actually resumes
## the day at the next slot — not just "the day eventually ends".
func test_picking_cook_hosts_the_pan_and_the_day_resumes() -> void:
	var main := _fresh_main()
	var host: Control = main.get_node("%MinigameHost")
	_walk(main, {}, "dinner")
	assert_eq(main.schedule.current(), "dinner", "the pan blocks advance() until it finishes")
	assert_eq(
		_current_minigame(host).scene_file_path,
		"res://scenes/minigames/cooking.tscn",
		"picking cook hosts the pan, not the next slot",
	)
	_current_minigame(host).finished.emit({"score": 1.0, "skipped": false})
	assert_eq(
		_current_minigame(host).scene_file_path,
		"res://scenes/minigames/freetime.tscn",
		"the day resumes at the next slot once the pan finishes",
	)


func test_chronic_lateness_eventually_makes_the_dog_sick() -> void:
	# sleep_energy["late"] is 35 and the carry blend trends toward it, so
	# without the ceiling a permanently-late dog never reaches the threshold of
	# 12 — only a single catastrophic day does. The ceiling makes chronic
	# lateness cost something.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	var nights := 0
	# Bounded, not a magic count. "Eventually" is the claim, and a fixed 10 would
	# make this test a hidden assertion about the accrual RATE — it would go red
	# on any legitimate T11 retune of sleep_debt_cap_minutes rather than on a
	# real regression. 20 is comfortably past the cap at any sane seed.
	while nights < 20 and not Difficulty.is_sick_morning(state.energy, cfg):
		state.bedtime = "late"
		state.brushed_today = true
		state.showered_today = true
		state.ledger.record_night(float(cfg.bed_mid_line_minutes) + 45.0,
				float(cfg.morning_start_minutes), cfg)
		state.refresh_ceiling(cfg)
		state.start_next_day(cfg)
		nights += 1
	assert_true(
		Difficulty.is_sick_morning(state.energy, cfg),
		"a fortnight of late nights running has to land the dog in bed",
	)
	assert_gt(nights, 3, "but not so fast that one bad week is a death spiral")
	assert_eq(
		DaySchedule.build(state, cfg), ["sick"], "and the schedule collapses to the sick beat"
	)
	gut.p("chronic-debt sick day reached at night %d — carry this into T11" % nights)


func test_the_wobble_telegraphs_the_debt_sick_day_a_night_early() -> void:
	# Every ladder/sick consequence telegraphs one day ahead. The ceiling adds a
	# new ROUTE to the sick morning, so the existing telegraph has to cover it —
	# it does, for free, because game.gd already runs is_sick_morning (in _show_summary) over
	# _tomorrow_energy and _tomorrow_energy clamps to the ceiling.
	var cfg := BalanceConfig.new()
	var main := _fresh_main()
	main.state.bedtime = "late"
	main.state.energy = 30.0
	main.state.ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	main.state.refresh_ceiling(cfg)
	assert_true(Difficulty.is_sick_morning(main._tomorrow_energy(), cfg))


func test_a_banked_week_absorbs_one_late_night_without_a_sick_day() -> void:
	# A good week buys ONE late night, not immunity — the other half of the cap.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	for _night in range(6):
		state.bedtime = "early"
		# INSIDE the loop: start_next_day resets brushed_today/showered_today at
		# its tail, so setting them once before the loop silently charges the
		# skip penalties on every iteration after the first and the bank never
		# gets a clean week to build from.
		state.brushed_today = true
		state.showered_today = true
		state.ledger.record_night(float(cfg.bed_early_line_minutes) - 60.0,
				float(cfg.morning_start_minutes), cfg)
		state.refresh_ceiling(cfg)
		state.start_next_day(cfg)
	assert_eq(state.energy_ceiling, 100.0, "a rested week carries no ceiling at all")
	state.bedtime = "late"
	state.brushed_today = true
	state.showered_today = true
	state.ledger.record_night(float(cfg.bed_mid_line_minutes) + 45.0,
			float(cfg.morning_start_minutes), cfg)
	state.refresh_ceiling(cfg)
	state.start_next_day(cfg)
	assert_false(
		Difficulty.is_sick_morning(state.energy, cfg), "one late night off a bank is survivable"
	)
	assert_lt(state.ledger.debt_minutes, 0.0, "and the bank absorbed it rather than going to debt")


func test_the_debt_never_shows_up_as_a_number_outside_the_sleep_beat() -> void:
	# Debt is minutes, and the game prints minutes, so the sleep beat's line is
	# legal. A persistent gauge is not — it violates the intent of the
	# energy-is-never-a-number rule even while obeying its letter.
	var cfg := BalanceConfig.new()
	var main := _fresh_main()
	main.state.ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	main.state.refresh_ceiling(cfg)
	main.schedule.set_slots(["freetime"] as Array[String])
	main._start_slot()
	await wait_physics_frames(2)
	for label_name in ["%ClockLabel", "%DogLabel", "%PosterLabel", "%DayLabel", "%RankLabel",
			"%StripLabel"]:
		var text: String = main.get_node(label_name).text
		assert_false(
			text.contains("behind") or text.contains("debt"),
			"%s is leaking the ledger into the HUD" % label_name,
		)


func test_playing_a_game_costs_the_evening_clock_its_price() -> void:
	# issue #12: each game costs the evening clock its price, so more games
	# move the bed minute. game.gd spends the clock — the minigame only
	# reports that a game finished.
	var main := _fresh_main()
	main.schedule.set_slots(["freetime"] as Array[String])
	main._start_slot()
	var host: Control = main.get_node("%MinigameHost")
	var node := _current_minigame(host)
	var before: float = main.clock.elapsed
	node.emit_signal("game_played")
	node.emit_signal("game_played")
	assert_eq(
		main.clock.elapsed,
		before + 2 * main.cfg.freetime_game_minutes,
		"two games played costs two game_played charges, no more no less",
	)


func test_a_finished_game_announces_itself() -> void:
	var scene: PackedScene = load("res://scenes/minigames/freetime.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({
		"pull_strength": 60.0,
		"dwell_time": 0.25,
		"pull_growth": 90.0,
		"pull_ceiling": 600.0,
	})
	watch_signals(node)
	node._cursor_pos = node._game_btn.get_rect().get_center()
	node._tick_dwell(10.0)
	assert_signal_emitted(node, "game_played")


## T11 round-1 instrument (user request): a lab preset that starts the day at
## post-work, so the five measurement evenings don't need a whole morning
## ridden first. start_from_slot is set BEFORE the node enters the tree, so
## _ready() sees it already set.
func test_start_from_slot_fast_forwards_past_the_morning() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.start_from_slot = "drive_home"
	add_child_autofree(main)
	assert_eq(main.schedule.current(), "drive_home", "the day fast-forwards past the morning")
	assert_true(main._evening, "entering an evening slot flips the evening clock")


## No guard on an unmatched name — pinned as the accepted dev-surface
## behaviour rather than silently fixed: the while loop walks to advance()
## returning false, which is the schedule's last slot.
func test_an_unmatched_start_from_slot_walks_to_the_last_slot() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	main.start_from_slot = "not_a_real_slot"
	add_child_autofree(main)
	assert_eq(main.schedule.current(), "sleep", "no match walks to the schedule's end")


func test_the_timer_bar_hides_while_the_minigame_has_no_countdown() -> void:
	var main := _fresh_main()
	var bar: Control = main.get_node("%TimerBar")
	main.schedule.set_slots(["coffee"] as Array[String])
	main._start_slot()
	main._process(0.0)
	assert_false(bar.visible, "an untimed game shows no bar")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the bar never eats a click")


func test_the_timer_bar_tracks_the_hosted_countdown() -> void:
	var main := _fresh_main()
	var bar: Range = main.get_node("%TimerBar")
	var node := _current_minigame(main.get_node("%MinigameHost"))
	node._start({"time_limit": 100.0})
	main._process(0.0)
	assert_true(bar.visible)
	assert_almost_eq(bar.value, 1.0, 0.0001, "a fresh countdown reads full")
	await wait_process_frames(5)
	main._process(0.0)
	assert_lt(bar.value, 1.0)
	assert_almost_eq(bar.value, node.time_fraction(), 0.0001)


func test_the_timer_bar_hides_once_the_hosted_game_is_gone() -> void:
	var main := _fresh_main()
	var host: Control = main.get_node("%MinigameHost")
	# A timed game followed by an untimed one, so only a lingering countdown
	# could show the bar.
	main.schedule.set_slots(["wake", "coffee"] as Array[String])
	main._start_slot()
	assert_true(_current_minigame(host).has_countdown(), "precondition: wake is timed")
	_current_minigame(host).finished.emit(DONE.duplicate())
	main._process(0.0)
	assert_false(main.get_node("%TimerBar").visible, "the finished game's countdown does not linger")


func test_every_hosted_game_gets_the_fail_gag_length() -> void:
	var main := _fresh_main()
	for slot in ["wake", "drive", "work_am", "freetime", "cooking"]:
		var params: Dictionary = main._hosted_params(slot)
		assert_eq(params.get("fail_gag_seconds"), main.cfg.fail_gag_seconds, slot)
		assert_true(params.has("rng"), slot)
	assert_true(main._hosted_params("cooking").has("tolerance"), "cooking keeps its difficulty params")


## Issue #17: the clock never fails a minigame, so drive and free time are
## judged at slot end — game.gd stamps the MISS before StatEffects runs, the
## same stamp-before-apply as the overrun and the band.
func _stamped(main: Control, slot: String) -> Dictionary:
	var result := {"score": 1.0, "skipped": false, "failed": false}
	main._on_finished(result, slot, autofree(Node.new()))
	return result


func test_arriving_past_eight_stamps_the_drive_a_miss() -> void:
	var main := _fresh_main()
	main.clock.spend(main.clock.budget + 5.0)
	var before: float = main.state.performance
	var energy: float = main.state.energy
	assert_true(_stamped(main, "drive").failed, "late is the drive's MISS")
	assert_almost_eq(
		main.state.performance,
		before - 5.0 * main.cfg.lateness_debit_per_min,
		0.0001,
		"the lateness debit is the whole charge — no generic loss cost on top",
	)
	assert_eq(main.state.energy, energy, "and no loss energy either")


func test_arriving_on_time_is_not_a_drive_miss() -> void:
	var main := _fresh_main()
	main.clock.spend(main.clock.budget - 1.0)
	assert_false(_stamped(main, "drive").failed)


func test_getting_home_by_the_line_stamps_the_drive_home_a_hit() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["drive_home", "dinner"] as Array[String])
	main._start_slot()
	main.clock.spend(main.cfg.home_budget() - 0.5)
	var result := _stamped(main, "drive_home")
	assert_false(result.failed)
	assert_eq(Verdict.of("drive_home", result), Verdict.HIT)


func test_getting_home_past_the_line_stamps_the_drive_home_a_miss() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["drive_home", "dinner"] as Array[String])
	main._start_slot()
	main.clock.spend(main.cfg.home_budget() + 0.5)
	var performance: float = main.state.performance
	var energy: float = main.state.energy
	var result := _stamped(main, "drive_home")
	assert_true(result.failed, "past home_by is the drive home's MISS")
	assert_eq(Verdict.of("drive_home", result), Verdict.MISS)
	# Wave-B ruling: the miss is paid through the evening clock and sleep.
	assert_eq(main.state.performance, performance, "no generic loss cost")
	assert_eq(main.state.energy, energy, "and no loss energy either")
	assert_eq(main.clock.elapsed, main.cfg.home_budget() + 0.5,
			"the stamp charges the evening clock nothing on top")


func test_a_late_band_night_stamps_free_time_a_miss() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["freetime", "sleep"] as Array[String])
	main._start_slot()
	main.clock.spend(main.cfg.evening_budget() + 1.0)
	var before: float = main.state.performance
	var result := _stamped(main, "freetime")
	assert_eq(result.band, "late", "precondition")
	assert_true(result.failed, "the late band is free time's MISS")
	assert_eq(main.state.performance, before, "the sleep ledger is the charge, not the loss cost")


func test_a_mid_band_night_is_not_a_free_time_miss() -> void:
	var main := _fresh_main()
	main.schedule.set_slots(["freetime", "sleep"] as Array[String])
	main._start_slot()
	main.clock.spend(main.cfg.evening_budget() - 1.0)
	var result := _stamped(main, "freetime")
	assert_eq(result.band, "mid", "precondition")
	assert_false(result.failed)


func test_the_drive_bar_shows_the_morning_left_to_eight() -> void:
	var main := _fresh_main()
	var bar: Range = main.get_node("%TimerBar")
	main.schedule.set_slots(["drive", "coffee"] as Array[String])
	main.clock.spend(20.0)
	main._start_slot()
	main._process(0.0)
	assert_true(bar.visible, "the commute shows a bar with no countdown of its own")
	var to_eight := float(main.cfg.work_start_minutes - main.cfg.morning_start_minutes) - 20.0
	assert_almost_eq(bar.value, to_eight / main.cfg.morning_budget(), 0.0001, "already part-drained")
	main.clock.spend(999.0)
	main._process(0.0)
	assert_true(bar.visible, "an empty bar still shows")
	assert_eq(bar.value, 0.0, "past 8:00 it reads empty")


func test_the_free_time_bar_shows_the_evening_left_to_the_mid_line() -> void:
	var main := _fresh_main()
	var bar: Range = main.get_node("%TimerBar")
	main.schedule.set_slots(["freetime", "sleep"] as Array[String])
	main._start_slot()
	main.clock.spend(30.0)
	main._process(0.0)
	assert_true(bar.visible)
	var to_mid := float(main.cfg.bed_mid_line_minutes - main.cfg.evening_start_minutes) - 30.0
	assert_almost_eq(bar.value, to_mid / main.cfg.evening_budget(), 0.0001)


func test_the_drive_home_bar_shows_the_evening_left_to_home_by() -> void:
	var main := _fresh_main()
	var bar: Range = main.get_node("%TimerBar")
	main.schedule.set_slots(["drive_home", "dinner"] as Array[String])
	main._start_slot()
	main._process(0.0)
	assert_true(bar.visible, "the drive home shows a bar with no countdown of its own")
	assert_almost_eq(bar.value, 1.0, 0.0001, "full as the dog leaves the office")
	main.clock.spend(4.0)
	main._process(0.0)
	assert_almost_eq(bar.value, (main.cfg.home_budget() - 4.0) / main.cfg.home_budget(), 0.0001)
	main.clock.spend(999.0)
	main._process(0.0)
	assert_true(bar.visible, "an empty bar still shows")
	assert_eq(bar.value, 0.0, "past home_by it reads empty")


func test_a_timed_slot_gets_its_time_limit_from_the_host() -> void:
	var main := _fresh_main()
	var energy: float = main.state.energy
	assert_eq(main._hosted_params("wake").time_limit, Difficulty.wake_params(energy, main.cfg).time_limit)
	assert_eq(main._hosted_params("cooking").time_limit, Difficulty.cooking_params(energy, main.cfg).time_limit)
	assert_true(
		_current_minigame(main.get_node("%MinigameHost")).has_countdown(),
		"wake is timed from the first frame",
	)


## Issue #17 revision: the gag is presentation, the loss cost is the penalty —
## so the clock holds still while a lost game plays its gag.
func test_the_clock_pauses_while_a_lost_game_gags() -> void:
	var main := _fresh_main()
	var node := _current_minigame(main.get_node("%MinigameHost"))
	main._process(1.0)
	var before: float = main.clock.elapsed
	assert_gt(before, 0.0, "precondition: the morning clock runs during wake")
	node._fail("💥")
	main._process(1.0)
	assert_eq(main.clock.elapsed, before, "no clock spent during the gag")


# --- verdict HUD (issue #17, commit 7) ----------------------------------------


func _stamp(main: Control) -> Label:
	return main.get_node("%StampLabel")


func _strip(main: Control) -> String:
	return (main.get_node("%StripLabel") as Label).text


## True while the newest hosted node is on its way out and nothing replaced it
## yet — the hold sits between two slots. Newest only: a test that reseeds the
## schedule leaves day 1's wake behind, un-driven, at the front of the host.
func _nothing_hosted(main: Control) -> bool:
	return _current_minigame(main.get_node("%MinigameHost")).is_queued_for_deletion()


func _finish(main: Control, slot: String, result: Dictionary) -> void:
	main._on_finished(result, slot, autofree(Node.new()))


func test_a_finished_game_stamps_hit_mid_screen_and_holds_the_next_slot() -> void:
	var main := _held_main()
	var host: Control = main.get_node("%MinigameHost")
	_current_minigame(host).finished.emit(DONE.duplicate())
	assert_true(_stamp(main).visible, "the stamp is up")
	assert_eq(_stamp(main).text, "HIT")
	assert_true(_nothing_hosted(main), "brush waits for the stamp")
	main._process(main.cfg.stamp_hold_seconds * 0.5)
	assert_true(_nothing_hosted(main), "still holding halfway through")
	main._process(main.cfg.stamp_hold_seconds * 0.5 + 0.01)
	assert_eq(_current_minigame(host).scene_file_path, "res://scenes/minigames/brush.tscn")
	assert_false(_stamp(main).visible, "the stamp clears as the next slot mounts")


func test_a_failed_game_stamps_miss() -> void:
	var main := _held_main()
	_current_minigame(main.get_node("%MinigameHost")).finished.emit(
		{"score": 0.0, "skipped": false, "failed": true}
	)
	assert_eq(_stamp(main).text, "MISS")


func test_a_skipped_chore_stamps_a_muted_skip() -> void:
	var main := _held_main()
	main.schedule.set_slots(["brush", "shower"] as Array[String])
	main._start_slot()
	_current_minigame(main.get_node("%MinigameHost")).finished.emit(SKIPPED.duplicate())
	assert_eq(_stamp(main).text, "SKIP")
	assert_lt(_stamp(main).get_theme_color("font_color").a, 1.0, "a skip is muted")


func test_a_slot_that_is_not_a_game_gets_no_stamp_and_no_hold() -> void:
	var main := _held_main()
	var host: Control = main.get_node("%MinigameHost")
	main.schedule.set_slots(["coffee", "work_am"] as Array[String])
	main._start_slot()
	_current_minigame(host).finished.emit(FAKE_RESULTS.coffee.duplicate())
	assert_false(_stamp(main).visible)
	assert_eq(_strip(main), "", "no mark for a card")
	assert_eq(main.schedule.current(), "work_am", "the next slot mounts at once")
	assert_false(_nothing_hosted(main))


func test_a_late_commute_stamps_miss_and_an_on_time_one_hit() -> void:
	var late := _held_main()
	late.clock.spend(late.clock.budget + 5.0)
	_finish(late, "drive", DONE.duplicate())
	assert_eq(_stamp(late).text, "MISS", "past 8:00 is the drive's MISS")
	var on_time := _held_main()
	on_time.clock.spend(on_time.clock.budget - 1.0)
	_finish(on_time, "drive", DONE.duplicate())
	assert_eq(_stamp(on_time).text, "HIT")


func test_a_late_band_night_stamps_free_time_miss_and_a_mid_one_hit() -> void:
	var late := _held_main()
	late.schedule.set_slots(["freetime", "sleep"] as Array[String])
	late._start_slot()
	late.clock.spend(late.cfg.evening_budget() + 1.0)
	_finish(late, "freetime", DONE.duplicate())
	assert_eq(_stamp(late).text, "MISS")
	var mid := _held_main()
	mid.schedule.set_slots(["freetime", "sleep"] as Array[String])
	mid._start_slot()
	mid.clock.spend(mid.cfg.evening_budget() - 1.0)
	_finish(mid, "freetime", DONE.duplicate())
	assert_eq(_stamp(mid).text, "HIT")


## The hold is presentation, exactly like the gag: the clock holds still, and
## the game's effects land once, before it.
func test_the_clock_holds_still_during_the_stamp_and_effects_land_once() -> void:
	var main := _held_main()
	main._process(1.0)
	_current_minigame(main.get_node("%MinigameHost")).finished.emit(
		{"score": 0.0, "skipped": false, "failed": true}
	)
	var elapsed: float = main.clock.elapsed
	var energy: float = main.state.energy
	var performance: float = main.state.performance
	main._process(main.cfg.stamp_hold_seconds * 0.5)
	assert_eq(main.clock.elapsed, elapsed, "no clock spent during the stamp")
	main._process(main.cfg.stamp_hold_seconds * 0.5 + 0.01)
	assert_eq(main.clock.elapsed, elapsed, "nor on the frame the hold ends")
	assert_eq(main.state.energy, energy, "the loss cost is not charged again after the hold")
	assert_eq(main.state.performance, performance)
	main._process(1.0)
	assert_almost_eq(main.clock.elapsed, elapsed + main.cfg.clock_scale, 0.001,
			"and the clock resumes with the next slot")


func test_a_held_commute_still_slinks_in_late_after_the_stamp() -> void:
	var main := _held_main()
	var host: Control = main.get_node("%MinigameHost")
	main.schedule.set_slots(["drive", "coffee"] as Array[String])
	main._start_slot()
	main.clock.spend(main.clock.budget + 5.0)
	_current_minigame(host).finished.emit(DONE.duplicate())
	assert_true(_nothing_hosted(main), "the late beat waits for the stamp too")
	main._process(main.cfg.stamp_hold_seconds + 0.01)
	assert_eq(_current_minigame(host).scene_file_path, "res://scenes/minigames/warning.tscn")
	assert_eq(main.schedule.current(), "drive", "still the out-of-band late beat")


func test_the_strip_marks_every_game_of_the_day_in_order() -> void:
	var main := _fresh_main()
	_walk(main, {
		"brush": SKIPPED,
		"breakfast": {"score": 0.0, "skipped": false, "failed": true},
		"lunch": {"score": 0.0, "skipped": false, "failed": true},
	})
	# wake brush shower clothes breakfast drive work_am lunch work_pm
	# drive_home cooking freetime — dinner and sleep leave no mark, and neither
	# does a coffee left to pass (the walk's water).
	assert_eq(_strip(main), "✅ – ✅ ✅ ❌ ✅ ✅ ❌ ✅ ✅ ✅ ✅")


func test_the_strip_starts_each_new_day_empty() -> void:
	var main := _fresh_main()
	_walk(main)
	assert_ne(_strip(main), "", "precondition: the day left marks")
	main._on_next_day_pressed()
	assert_eq(_strip(main), "")
	_current_minigame(main.get_node("%MinigameHost")).finished.emit(DONE.duplicate())
	assert_eq(_strip(main), "✅", "the new day's first game is its first mark")


func test_restarting_clears_the_strip() -> void:
	var main := _fresh_main()
	_current_minigame(main.get_node("%MinigameHost")).finished.emit(DONE.duplicate())
	assert_eq(_strip(main), "✅", "precondition")
	main._on_restart_pressed()
	assert_eq(_strip(main), "")


## Neither the default font nor a web build's system has these glyphs; the HUD
## labels fall back to the bundled Twemoji, as the listening bubble does.
func test_the_emoji_hud_labels_can_draw_their_glyphs() -> void:
	var main := _fresh_main()
	var poster_font: Font = (main.get_node("%PosterLabel") as Label).get_theme_font(&"font")
	var strip_font: Font = (main.get_node("%StripLabel") as Label).get_theme_font(&"font")
	assert_true(_draws(poster_font, "🦴"), "the bone")
	for mark in Verdict.MARKS.values():
		assert_true(_draws(strip_font, mark), "strip mark %s" % mark)


func _draws(font: Font, glyph: String) -> bool:
	if font.has_char(glyph.unicode_at(0)):
		return true
	for fallback in font.fallbacks:
		if (fallback as Font).has_char(glyph.unicode_at(0)):
			return true
	return false


func test_breakfast_speed_rides_the_days_progress() -> void:
	var main := _fresh_main()
	main.cfg.day_ramp_speed_max = 2.0
	var host: Control = main.get_node("%MinigameHost")
	for slot in ["wake", "brush", "shower", "clothes"]:
		_current_minigame(host).finished.emit(_result_for(slot, {}))
	assert_eq(main.schedule.current(), "breakfast")
	# Four of the day's twelve games are behind it: 1 + 4 / 12 * (2.0 - 1).
	assert_almost_eq(main._params_for("breakfast").speed,
			main.cfg.breakfast_beat_speed * (1.0 + 4.0 / 12.0), 0.0001)


func test_coffee_is_the_cup_grab_and_its_cup_rides_the_days_progress() -> void:
	var main := _fresh_main()
	main.cfg.day_ramp_speed_max = 2.0
	main.schedule.set_slots(["wake", "coffee", "work_am"] as Array[String])
	main._start_slot()
	var host: Control = main.get_node("%MinigameHost")
	_current_minigame(host).finished.emit(_result_for("wake", {}))
	assert_eq(main.schedule.current(), "coffee")
	assert_true(_current_minigame(host).session() is CoffeeSession, "the cart hosts the cup grab")
	# One of the day's three games is behind it: 1 + 1 / 3 * (2.0 - 1).
	assert_almost_eq(main._params_for("coffee").speed,
			main.cfg.coffee_cup_speed * (1.0 + 1.0 / 3.0), 0.0001)


func test_a_dog_that_cannot_pay_gets_a_cup_it_cannot_grab() -> void:
	var main := _fresh_main()
	main.state.wallet.savings = main.cfg.coffee_price - 1
	assert_false(main._params_for("coffee").can_afford)
	main.state.wallet.savings = main.cfg.coffee_price
	assert_true(main._params_for("coffee").can_afford, "exactly the price is enough")


func test_a_clean_grab_stamps_a_hit_and_a_spill_a_miss_but_water_stamps_nothing() -> void:
	var grab := _held_main()
	_finish(grab, "coffee", BUY_COFFEE.duplicate())
	assert_eq(_stamp(grab).text, "HIT")
	assert_eq(_strip(grab), "✅")
	var spill := _held_main()
	_finish(spill, "coffee", SPILL_COFFEE.duplicate())
	assert_eq(_stamp(spill).text, "MISS")
	assert_eq(_strip(spill), "❌")
	var water := _held_main()
	_finish(water, "coffee", FAKE_RESULTS.coffee.duplicate())
	assert_false(_stamp(water).visible, "letting it pass is a choice, not a result")
	assert_eq(_strip(water), "")


func test_a_spilled_cup_costs_the_price_and_nothing_else() -> void:
	var spiller := _fresh_main()
	spiller.state.wallet.savings = 20
	_walk(spiller, {"coffee": SPILL_COFFEE}, "coffee")
	var sober := _fresh_main()
	sober.state.wallet.savings = 20
	_walk(sober, {}, "coffee")
	assert_eq(spiller.state.wallet.savings, 20 - spiller.cfg.coffee_price, "the cart took its five")
	assert_false(spiller.state.coffee_today, "and there is no coffee")
	assert_eq(spiller.state.energy, sober.state.energy, "no loss energy cost")
	assert_eq(spiller.state.performance, sober.state.performance, "no loss performance cost")


func test_work_am_is_the_word_burst_and_its_words_ride_the_days_progress() -> void:
	var main := _fresh_main()
	main.cfg.day_ramp_speed_max = 2.0
	main.schedule.set_slots(["wake", "work_am", "lunch", "work_pm"] as Array[String])
	main._start_slot()
	var host: Control = main.get_node("%MinigameHost")
	_current_minigame(host).finished.emit(_result_for("wake", {}))
	assert_eq(main.schedule.current(), "work_am")
	assert_true(_current_minigame(host).has_method("session"), "work AM hosts the burst")
	# One of the day's four games is behind it: 1 + 0.25 * (2.0 - 1).
	assert_almost_eq(main._params_for("work_am").speed, 1.25, 0.0001)


func test_work_pm_is_the_inbox_triage_and_its_mail_rides_the_days_progress() -> void:
	var main := _fresh_main()
	main.cfg.day_ramp_speed_max = 2.0
	main.schedule.set_slots(["wake", "work_am", "lunch", "work_pm"] as Array[String])
	main._start_slot()
	var host: Control = main.get_node("%MinigameHost")
	for slot in ["wake", "work_am", "lunch"]:
		_current_minigame(host).finished.emit(_result_for(slot, {}))
	assert_eq(main.schedule.current(), "work_pm")
	assert_true(_current_minigame(host).session() is TriageSession, "work PM hosts the triage")
	# Three of the day's four games are behind it: 1 + 0.75 * (2.0 - 1).
	assert_almost_eq(main._params_for("work_pm").speed, 1.75, 0.0001)
