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


func test_dinner_cook_beats_takeout() -> void:
	var s2 := GameState.new()
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "cook"}, state, cfg)
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "takeout"}, s2, cfg)
	assert_gt(state.energy, s2.energy)


func test_bedtime_derives_from_games_played() -> void:
	assert_eq(StatEffects.derive_bedtime(0), "early")
	assert_eq(StatEffects.derive_bedtime(1), "mid")
	assert_eq(StatEffects.derive_bedtime(2), "late")
	assert_eq(StatEffects.derive_bedtime(9), "late")


func test_freetime_drains_once_per_game_played() -> void:
	var before := state.energy
	var result := {"score": 0.3, "skipped": false, "choice": "logoff", "games_played": 3}
	StatEffects.apply("freetime", result, state, cfg)
	assert_eq(state.energy, before - cfg.late_game_drain * 3.0)
	assert_true(state.played_late)
	assert_eq(state.bedtime, "late")


func test_freetime_with_no_games_is_an_early_night() -> void:
	state.played_late = true
	var before := state.energy
	var result := {"score": 1.0, "skipped": false, "choice": "logoff", "games_played": 0}
	StatEffects.apply("freetime", result, state, cfg)
	assert_eq(state.energy, before)
	assert_false(state.played_late)
	assert_eq(state.bedtime, "early")


func test_freetime_one_game_is_a_mid_bedtime() -> void:
	var result := {"score": 0.5, "skipped": false, "choice": "logoff", "games_played": 1}
	StatEffects.apply("freetime", result, state, cfg)
	assert_eq(state.bedtime, "mid")


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
