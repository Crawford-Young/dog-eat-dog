extends GutTest

## Scene-level smoke: walk main.tscn through every slot of a day by faking each
## minigame's finished signal. Catches host wiring, per-slot params and the
## summary hand-off — not per-minigame behaviour, which its own suite covers.
##
## Wave 2: the day list is built fresh every morning (sick short-circuit, retire
## offer, warning beat, coffee cart), so every walk drives
## DaySchedule.build(state, cfg) — never a fixed slot list.

const FAKE_RESULTS := {
	"coffee": {"score": 1.0, "skipped": false, "choice": "skip"},
	"dinner": {"score": 1.0, "skipped": false, "choice": "cook"},
	"freetime": {"score": 0.33, "skipped": false, "choice": "logoff", "games_played": 2},
	"retire_offer": {"score": 1.0, "skipped": false, "choice": "stay"},
}
const BUY_COFFEE := {"score": 1.0, "skipped": false, "choice": "buy"}
const RETIRE := {"score": 1.0, "skipped": false, "choice": "retire"}
const BAD_WORK := {"score": 0.0, "skipped": false}


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
	return overrides.get(slot, FAKE_RESULTS.get(slot, {"score": 1.0, "skipped": false}))


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


func test_freetime_games_decide_the_bedtime_the_sleep_beat_narrates() -> void:
	var main := _fresh_main()
	_walk(main)
	assert_eq(main.state.bedtime, "late", "two games played means a late night")
	assert_true(main.state.played_late)


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
	var buyer := _fresh_main()
	buyer.state.wallet.savings = 20
	_walk(buyer, {"coffee": BUY_COFFEE}, "coffee")
	var sober := _fresh_main()
	sober.state.wallet.savings = 20
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
		["wake", "brush", "coffee", "work_am", "lunch", "work_pm", "dinner", "freetime", "sleep"],
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
	var main := _fresh_main()
	_walk(main, {"work_am": BAD_WORK, "work_pm": BAD_WORK})
	assert_string_contains(_summary_text(main), "the cat glanced at your screen today. twice.")
	main._on_next_day_pressed()
	assert_true(
		DaySchedule.build(main.state, main.cfg).has("warning"),
		"the warning beat is on tomorrow's list",
	)


func test_the_summary_telegraphs_a_tomorrow_that_might_not_happen() -> void:
	# Wave-2 QA ruling (issue #5): next-day energy now blends leftover energy
	# with the bedtime target (energy_carry_weight, default 0.5), so a wrecked
	# bedtime target alone no longer guarantees a sick warning — it has to
	# clear the threshold together with whatever energy is left at day's end
	# (30.0 for this fixed walk: 0.5*30 + 0.5*late < sick_energy_threshold).
	var main := _fresh_main()
	var wrecked := BalanceConfig.new()
	wrecked.sleep_energy = {"early": 90.0, "mid": 65.0, "late": -10.0}
	main.cfg = wrecked
	_walk(main)
	assert_string_contains(_summary_text(main), "tomorrow might not happen")
	var rested := _fresh_main()
	_walk(rested)
	assert_false(
		_summary_text(rested).contains("tomorrow might not happen"),
		"a night that only ends tired says nothing",
	)
