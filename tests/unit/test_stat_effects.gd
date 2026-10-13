extends GutTest

var cfg: BalanceConfig
var state: GameState


func before_each() -> void:
	cfg = BalanceConfig.new()
	state = GameState.new()


func test_wake_changes_nothing() -> void:
	var before := state.energy
	StatEffects.apply("wake", {"score": 1.0, "skipped": false}, state, cfg)
	assert_eq(state.energy, before)
	assert_almost_eq(state.performance, 0.5, 0.001)


func test_brush_done_restores_energy_and_flags() -> void:
	var before := state.energy
	StatEffects.apply("brush", {"score": 1.0, "skipped": false}, state, cfg)
	assert_eq(state.energy, before + cfg.selfcare_restore)
	assert_true(state.brushed_today)


func test_brush_skipped_no_restore() -> void:
	var before := state.energy
	StatEffects.apply("brush", {"score": 0.0, "skipped": true}, state, cfg)
	assert_eq(state.energy, before)
	assert_false(state.brushed_today)


func test_shower_restores_and_flags() -> void:
	var s := GameState.new()
	s.energy = 50.0
	StatEffects.apply("shower", {"score": 1.0, "skipped": false}, s, cfg)
	assert_almost_eq(s.energy, 50.0 + cfg.selfcare_restore, 0.001)
	assert_true(s.showered_today)


func test_shower_skip_no_restore_no_flag() -> void:
	var s := GameState.new()
	s.energy = 50.0
	StatEffects.apply("shower", {"score": 0.0, "skipped": true}, s, cfg)
	assert_almost_eq(s.energy, 50.0, 0.001)
	assert_false(s.showered_today)


func test_clothes_changes_nothing() -> void:
	# Getting dressed is mandatory — fumbling already costs clock time, which
	# is the whole consequence. Nothing reaches state.
	var before := state.energy
	StatEffects.apply("clothes", {"score": 0.0, "skipped": false}, state, cfg)
	assert_eq(state.energy, before)
	assert_almost_eq(state.performance, 0.5, 0.001)


func test_breakfast_refill_scales_with_score() -> void:
	var s := GameState.new()
	s.energy = 50.0
	StatEffects.apply("breakfast", {"score": 1.0, "skipped": false}, s, cfg)
	assert_almost_eq(s.energy, 50.0 + cfg.breakfast_energy_max, 0.001)
	var s2 := GameState.new()
	s2.energy = 50.0
	StatEffects.apply("breakfast", {"score": 0.0, "skipped": false}, s2, cfg)
	assert_almost_eq(s2.energy, 50.0 + cfg.breakfast_energy_min, 0.001)


func test_breakfast_skip_costs_energy() -> void:
	var s := GameState.new()
	s.energy = 50.0
	StatEffects.apply("breakfast", {"score": 0.0, "skipped": true}, s, cfg)
	assert_almost_eq(s.energy, 50.0 - cfg.skip_breakfast_penalty, 0.001)


func test_drive_on_time_no_debit() -> void:
	var s := GameState.new()
	s.performance = 0.6
	StatEffects.apply("drive", {"score": 1.0, "overrun": 0.0}, s, cfg)
	assert_almost_eq(s.performance, 0.6, 0.001)


func test_drive_late_debits_performance() -> void:
	var s := GameState.new()
	s.performance = 0.6
	StatEffects.apply("drive", {"score": 1.0, "overrun": 10.0}, s, cfg)
	assert_almost_eq(s.performance, 0.6 - 10.0 * cfg.lateness_debit_per_min, 0.001)


func test_drive_debit_caps() -> void:
	var s := GameState.new()
	s.performance = 0.6
	StatEffects.apply("drive", {"score": 1.0, "overrun": 500.0}, s, cfg)
	assert_almost_eq(s.performance, 0.6 - cfg.lateness_debit_cap, 0.001)


func test_work_records_score_and_drains() -> void:
	var before_e := state.energy
	StatEffects.apply("work_am", {"score": 1.0, "skipped": false}, state, cfg)
	assert_almost_eq(state.performance, 0.65, 0.001)
	assert_eq(state.energy, before_e - cfg.work_drain)


func test_lunch_restores_energy() -> void:
	var before := state.energy
	StatEffects.apply("lunch", {"score": 1.0, "skipped": false}, state, cfg)
	assert_eq(state.energy, before + cfg.lunch_restore)


func test_lunch_does_not_touch_performance() -> void:
	StatEffects.apply("lunch", {"score": 0.0, "skipped": false}, state, cfg)
	assert_almost_eq(state.performance, 0.5, 0.001)


## The pan pays the cooking energy, scaled by how the cooking session actually
## went — a bad cook can score below takeout's flat gain. The dinner walk
## itself pays none (see test_the_dinner_walk_itself_pays_no_cooking_energy).
func test_cooking_pays_energy_by_how_well_it_went() -> void:
	var cfg := BalanceConfig.new()
	var clean := GameState.new()
	var burnt := GameState.new()
	clean.energy = 50.0
	burnt.energy = 50.0
	StatEffects.apply("cooking", {"score": 1.0, "skipped": false}, clean, cfg)
	StatEffects.apply("cooking", {"score": 0.0, "skipped": false}, burnt, cfg)
	assert_eq(clean.energy, 50.0 + cfg.cook_energy_max)
	assert_eq(burnt.energy, 50.0 + cfg.cook_energy_min)
	assert_gt(clean.energy, burnt.energy, "a good meal is worth more than a bad one")


func test_takeout_costs_money_and_cooking_costs_none() -> void:
	# The first time the wallet buys TIME. The morning has no equivalent —
	# skipping a chore costs clock there, never saves it.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	state.wallet.savings = 100
	StatEffects.apply("dinner", {"choice": "takeout", "score": 1.0}, state, cfg)
	assert_eq(state.wallet.savings, 100 - cfg.takeout_price)
	var cook := GameState.new()
	cook.wallet.savings = 100
	StatEffects.apply("dinner", {"choice": "cook", "score": 1.0}, cook, cfg)
	assert_eq(cook.wallet.savings, 100, "cooking is free, it just is not fast")


func test_the_dinner_walk_itself_pays_no_cooking_energy() -> void:
	# One meal, one energy source: the pan grants it, scaled by the score.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	state.energy = 50.0
	StatEffects.apply("dinner", {"choice": "cook", "score": 1.0}, state, cfg)
	assert_eq(state.energy, 50.0)


func test_freetime_takes_its_bedtime_from_the_clock_not_the_game_count() -> void:
	# Bedtime derives from the evening clock now. game.gd stamps the band and
	# the bed minute onto the result, exactly as it stamps the morning's overrun
	# onto the drive result — StatEffects never touches a clock itself.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	StatEffects.apply(
		"freetime", {"games_played": 0, "band": "late", "bed_minute": 1421.0}, state, cfg
	)
	assert_eq(state.bedtime, "late", "zero games can still be a late night if you dawdled")


func test_freetime_records_the_night_on_the_ledger() -> void:
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	StatEffects.apply(
		"freetime", {"games_played": 4, "band": "late", "bed_minute": 1421.0}, state, cfg
	)
	assert_eq(state.ledger.debt_minutes, 41.0, "a 23:41 bed is 41 minutes past the square 23:00")
	assert_lt(state.energy_ceiling, 100.0, "and the ceiling drops the same night")


func test_a_long_evening_of_games_drains_no_energy_directly() -> void:
	# Games cost CLOCK, and the clock costs
	# sleep, and the sleep costs energy — one chain, one authority.
	var cfg := BalanceConfig.new()
	var state := GameState.new()
	state.energy = 60.0
	StatEffects.apply(
		"freetime", {"games_played": 6, "band": "late", "bed_minute": 1421.0}, state, cfg
	)
	assert_eq(state.energy, 60.0, "the games themselves take nothing")


func test_sleep_is_a_no_op_because_bedtime_is_already_derived() -> void:
	state.bedtime = "late"
	var before := state.energy
	StatEffects.apply("sleep", {"score": 1.0, "skipped": false}, state, cfg)
	assert_eq(state.bedtime, "late")
	assert_eq(state.energy, before)


func test_coffee_buy_spends_and_flags() -> void:
	var s := GameState.new()
	s.wallet.credit(10)
	StatEffects.apply("coffee", {"score": 1.0, "skipped": false, "choice": "buy"}, s, cfg)
	assert_true(s.coffee_today)
	assert_eq(s.wallet.savings, 10 - cfg.coffee_price)


func test_coffee_skip_costs_nothing() -> void:
	var s := GameState.new()
	StatEffects.apply("coffee", {"score": 1.0, "skipped": false, "choice": "skip"}, s, cfg)
	assert_false(s.coffee_today)
	assert_eq(s.wallet.savings, 0)


func test_coffee_spill_pays_the_price_and_buys_no_focus() -> void:
	var s := GameState.new()
	s.wallet.credit(10)
	var before := s.energy
	var performance := s.performance
	StatEffects.apply("coffee",
			{"score": 0.0, "skipped": false, "failed": true, "choice": "spill"}, s, cfg)
	assert_eq(s.wallet.savings, 10 - cfg.coffee_price, "the cart still takes its five")
	assert_false(s.coffee_today, "and the cup is on the floor")
	assert_eq(s.energy, before, "money is the whole cost: no loss energy")
	assert_eq(s.performance, performance, "nor a loss performance cost")


## A dinner that timed out is the sad kibble (#18): no takeout energy, no
## takeout bill, and the generic loss cost, since nothing else charges it.
func test_a_timed_out_dinner_is_kibble_and_pays_the_loss_cost() -> void:
	var s := GameState.new()
	s.wallet.credit(50)
	s.energy = 50.0
	StatEffects.apply("dinner", {"score": 0.0, "skipped": false, "failed": true}, s, cfg)
	assert_eq(s.wallet.savings, 50, "no takeout was ordered")
	assert_almost_eq(s.energy, 50.0 - cfg.fail_energy_cost, 0.0001,
			"no dinner energy, and the loss energy on top")
	assert_almost_eq(s.performance, 0.5 - cfg.fail_performance_cost, 0.0001)


func test_coffee_is_not_a_loss_cost_slot() -> void:
	assert_false("coffee" in StatEffects.LOSS_COST_SLOTS)


func test_coffee_crash_drains_after_morning_work() -> void:
	var sober := GameState.new()
	sober.energy = 80.0
	StatEffects.apply("work_am", {"score": 0.5, "skipped": false}, sober, cfg)
	var wired := GameState.new()
	wired.energy = 80.0
	wired.coffee_today = true
	StatEffects.apply("work_am", {"score": 0.5, "skipped": false}, wired, cfg)
	assert_eq(wired.energy, sober.energy - cfg.coffee_crash_drain)


func test_takeout_costs_money_cook_is_free() -> void:
	var s := GameState.new()
	s.wallet.credit(50)
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "takeout"}, s, cfg)
	assert_eq(s.wallet.savings, 50 - cfg.takeout_price)
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "cook"}, s, cfg)
	assert_eq(s.wallet.savings, 50 - cfg.takeout_price)


func test_sick_beat_sets_recovery_from_mash_score() -> void:
	var s := GameState.new()
	StatEffects.apply("sick", {"score": 1.0, "skipped": false}, s, cfg)
	assert_true(s.sick_today)
	assert_eq(s.sick_recovery, cfg.sick_reset_max)
	StatEffects.apply("sick", {"score": 0.0, "skipped": false}, s, cfg)
	assert_eq(s.sick_recovery, cfg.sick_reset_min)


func test_close_day_pays_rank_salary_and_drains_living_cost() -> void:
	# QA ruling (issue #8): the day nets the margin over living costs, not the
	# raw salary — pay lands first, then the drain.
	var s := GameState.new()
	s.rank = 1
	var report := StatEffects.close_day(s, cfg)
	assert_eq(report.pay, cfg.salaries[1])
	assert_eq(report.cost, cfg.daily_living_cost)
	assert_eq(
		s.wallet.savings,
		cfg.salaries[1] - cfg.daily_living_cost,
		"a working day nets the margin over living costs",
	)


func test_close_day_sick_no_pay_no_ladder() -> void:
	var s := GameState.new()
	s.sick_today = true
	s.performance = 0.0
	var report := StatEffects.close_day(s, cfg)
	assert_eq(report.pay, 0)
	assert_eq(report.cost, 0, "no savings to drain, so nothing is taken")
	assert_eq(s.wallet.savings, 0)
	assert_false(s.warning)
	assert_eq(report.events, ["sick_no_pay"])


func test_close_day_sick_drains_savings_but_never_negative() -> void:
	# Money-never-negative invariant pin (issue #8 ruling: sick days cost
	# money too): a sick day still tries to take the full living cost, but
	# clamps at whatever savings actually exist.
	var s := GameState.new()
	s.sick_today = true
	s.wallet.credit(20)
	var report := StatEffects.close_day(s, cfg)
	assert_eq(report.pay, 0)
	assert_eq(report.cost, 20, "only the 20 that existed gets drained")
	assert_eq(s.wallet.savings, 0)


func test_close_day_no_longer_evaluates_the_ladder() -> void:
	# QA ruling (issue #10 / finding 1): rank news moved to a same-day office
	# beat fired right after work_pm (game.gd), not close_day. close_day now
	# always reports an empty events array on a normal day.
	var s := GameState.new()
	s.performance = 0.1
	var report := StatEffects.close_day(s, cfg)
	assert_eq(report.events, [])
	assert_false(s.warning, "the ladder never ran, so no warning is raised here")


## The same slot result, played to the end or lost — so a test compares only
## what `failed` itself costs, on top of whatever the slot already does.
func _won_and_lost(slot: String, result: Dictionary) -> Array[GameState]:
	var won := GameState.new()
	var lost := GameState.new()
	for s in [won, lost]:
		s.energy = 50.0
		s.performance = 0.5
	var lost_result := result.duplicate()
	lost_result["failed"] = true
	StatEffects.apply(slot, result.duplicate(), won, cfg)
	StatEffects.apply(slot, lost_result, lost, cfg)
	return [won, lost]


func test_a_lost_chore_costs_performance_and_energy_on_top() -> void:
	# brush and shower also forfeit their restore — pinned on their own below.
	for slot in ["wake", "clothes", "breakfast", "lunch", "dinner", "cooking"]:
		var pair := _won_and_lost(slot, {"score": 0.0, "skipped": false})
		assert_almost_eq(pair[0].performance - pair[1].performance,
				cfg.fail_performance_cost, 0.0001, "%s pays the performance cost" % slot)
		assert_almost_eq(pair[0].energy - pair[1].energy,
				cfg.fail_energy_cost, 0.0001, "%s pays the energy cost" % slot)


func test_a_lost_chore_keeps_the_slots_own_effects() -> void:
	var pair := _won_and_lost("brush", {"score": 0.0, "skipped": false})
	assert_true(pair[1].brushed_today, "a lost brush still counts as brushed")


func test_slots_that_already_charge_a_miss_never_pay_the_loss_cost() -> void:
	# Drive's miss is the lateness debit, work's is the score EMA and free
	# time's is the sleep ledger (user ruling, issue #17): no double charge.
	var results := {
		"drive": {"score": 0.0, "skipped": false, "overrun": 10.0},
		"work_am": {"score": 0.0, "skipped": false},
		"work_pm": {"score": 0.0, "skipped": false},
		"freetime": {"score": 0.0, "skipped": false, "band": "late", "bed_minute": 1500.0},
	}
	for slot in results:
		var pair := _won_and_lost(slot, results[slot])
		assert_almost_eq(pair[1].performance, pair[0].performance, 0.0001, slot)
		assert_almost_eq(pair[1].energy, pair[0].energy, 0.0001, slot)


func test_the_loss_cost_clamps_performance_at_zero() -> void:
	state.performance = 0.005
	StatEffects.apply("wake", {"score": 0.0, "skipped": false, "failed": true}, state, cfg)
	assert_eq(state.performance, 0.0)


func test_the_loss_cost_defaults_match_the_ruling() -> void:
	assert_eq(cfg.fail_performance_cost, 0.01)
	assert_eq(cfg.fail_energy_cost, 3.0)


## Issue #17 revision: a lost brush or shower forfeits selfcare_restore but
## still counts as done, so tomorrow's skip penalty does not land. Net: the
## loss energy cost alone.
func test_a_lost_brush_or_shower_forfeits_its_restore() -> void:
	for slot in ["brush", "shower"]:
		var s := GameState.new()
		s.energy = 50.0
		s.performance = 0.5
		StatEffects.apply(slot, {"score": 0.0, "skipped": false, "failed": true}, s, cfg)
		assert_almost_eq(s.energy, 50.0 - cfg.fail_energy_cost, 0.0001, "%s nets the loss cost only" % slot)
		assert_almost_eq(s.performance, 0.5 - cfg.fail_performance_cost, 0.0001, slot)


func test_a_lost_shower_still_counts_as_showered() -> void:
	var pair := _won_and_lost("shower", {"score": 0.0, "skipped": false})
	assert_true(pair[1].showered_today, "no stink line, no skip penalty tomorrow")
