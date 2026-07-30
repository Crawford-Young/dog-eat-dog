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


func _fresh_main() -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	return main


## The morning rebuild game.gd runs at _ready and at next-day, for tests that
## seed state after instantiation. The day-1 minigame already hosted is left
## behind un-driven — _current_minigame always walks from the back.
func _reseed(main: Control) -> void:
	main.schedule.set_slots(DaySchedule.build(main.state, main.cfg))
	main._start_slot()


func _result_for(slot: String, overrides: Dictionary) -> Dictionary:
	# .duplicate() is load-bearing now that T5 stamps onto the freetime result
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


## QA ruling (issue #10 / finding 1): promotion/demotion/warning news is now a
## same-day office beat hosted right after work_pm, OUTSIDE the normal slot
## schedule — schedule.current() stays "work_pm" (advance() never ran) while
## it's up. Drive it like any other beat before the walk moves on, unless the
## caller stopped exactly at "work_pm" to inspect the pending beat itself.
func _finish_rank_news_beat_if_pending(main: Control, host: Control) -> void:
	if main.schedule.current() != "work_pm":
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


func test_the_poster_tracks_rank_and_savings() -> void:
	var main := _fresh_main()
	var poster: Label = main.get_node("%PosterLabel")
	assert_eq(poster.text, "mailroom · savings 0 / %d" % main.cfg.retirement_target)
	_walk(main)
	main._on_next_day_pressed()
	assert_eq(
		poster.text,
		"mailroom · savings %d / %d" % [
			main.cfg.salaries[0] - main.cfg.daily_living_cost, main.cfg.retirement_target
		],
		"the poster refreshes on the next morning's first slot",
	)


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


func test_coffee_lifts_the_morning_typing_tier_only() -> void:
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
	assert_gt(buyer._params_for("work_am").tier, clear, "coffee lifts the morning typing tier")
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
	# QA ruling (issue #10 / finding 1): the "warned" news now lands as a
	# same-day office beat right after work_pm, not in the day-end summary.
	var main := _fresh_main()
	_walk(main, {"work_am": BAD_WORK, "work_pm": BAD_WORK}, "work_pm")
	var host: Control = main.get_node("%MinigameHost")
	var beat := _current_minigame(host)
	beat._typer.skip()
	assert_string_contains(
		(beat.get_node("%Line") as Label).text,
		"the cat glanced at your screen today. twice.",
		"the office delivers the news same-day now",
	)
	beat.finished.emit({"score": 1.0, "skipped": false})
	for slot in ["drive_home", "dinner", "freetime", "sleep"]:
		_current_minigame(host).finished.emit(_result_for(slot, {}))
	assert_false(
		_summary_text(main).contains("the cat glanced at your screen today. twice."),
		"rank news no longer repeats in the day-end summary",
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
	assert_true(
		(main.get_node("%Summary") as Panel).visible, "the day still closes on a summary afterward"
	)


func test_the_summary_telegraphs_a_tomorrow_that_might_not_happen() -> void:
	# Wave-2 QA ruling (issue #5): next-day energy now blends leftover energy
	# with the bedtime target (energy_carry_weight, default 0.5), so a wrecked
	# bedtime target alone no longer guarantees a sick warning — it has to clear
	# the threshold together with whatever energy is left at day's end (44.0 for
	# this fixed walk, now that the wave-3a morning restores on shower and
	# breakfast: 0.5*44 + 0.5*wrecked < sick_energy_threshold).
	#
	# Wave 3b: bedtime comes from the evening clock's band, not the game count,
	# so a synchronous walk's band is no longer this test's business — every
	# band is wrecked, and the telegraph is what is under test either way.
	var main := _fresh_main()
	var wrecked := BalanceConfig.new()
	wrecked.sleep_energy = {"early": -60.0, "mid": -60.0, "late": -60.0}
	main.cfg = wrecked
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


func test_both_work_shifts_read_the_dogs_rank_for_their_par() -> void:
	var main := _fresh_main()
	main.state.rank = 2
	assert_eq(main._params_for("work_am").par_units, main.cfg.typing_par_units[2])
	assert_eq(main._params_for("work_pm").par_units, main.cfg.typing_par_units[2])


func test_the_morning_budget_is_derived_from_the_arrival_deadline() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(cfg.work_start_minutes, 480, "work starts at 8:00")
	# Asserted as the RELATION, not as a literal. The deadline is the round's
	# primary feel lever and has moved three times (510 -> 525 -> 480); what must
	# never change is that the budget is derived from it rather than stored
	# beside it.
	assert_eq(cfg.morning_budget(), float(cfg.work_start_minutes - cfg.morning_start_minutes),
			"the morning is the gap to the deadline")
	assert_eq(cfg.morning_budget(), 60.0, "and that gap is currently 60 minutes")
	assert_eq(_fresh_main().clock.budget, cfg.morning_budget(),
			"the clock is built from the derived budget, not a standalone tunable")


func test_the_evening_budget_is_derived_from_the_last_band_line() -> void:
	# Same rule as morning_budget: the LINE is the stored design intent and the
	# span is computed. A stored evening_budget_minutes would split the
	# authority — the retired morning_budget_minutes is the precedent.
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
	# mode this exists to prevent — the 3a reflect measured the morning commute
	# at ~33 of the morning's ~44 minutes already.
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
## it shipped the wrong way round and the clock was invisible for the entire
## drive, with every other clock test passing because the label was updating
## correctly the whole time — it was just behind the road.
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
