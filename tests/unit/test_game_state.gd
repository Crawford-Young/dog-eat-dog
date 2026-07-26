extends GutTest

var cfg: BalanceConfig


func before_each() -> void:
	cfg = BalanceConfig.new()


func test_energy_clamps_high() -> void:
	var s := GameState.new()
	s.apply_energy(500.0)
	assert_eq(s.energy, 100.0)


func test_energy_clamps_low() -> void:
	var s := GameState.new()
	s.apply_energy(-500.0)
	assert_eq(s.energy, 0.0)


func test_work_score_rolls_toward_new_score() -> void:
	var s := GameState.new()
	s.performance = 0.5
	s.record_work_score(1.0)
	assert_almost_eq(s.performance, 0.65, 0.001)  # 0.5*0.7 + 1.0*0.3


func test_next_day_sets_energy_from_bedtime() -> void:
	# Wave-2 QA ruling (issue #5): sleep blends leftover energy with the
	# bedtime target — no longer a full reset. 0.5*50 + 0.5*90 = 70.0.
	var s := GameState.new()
	s.energy = 50.0
	s.bedtime = "early"
	s.brushed_today = true
	s.start_next_day(cfg)
	assert_eq(s.day, 2)
	assert_almost_eq(s.energy, 70.0, 0.001)
	assert_false(s.brushed_today)


func test_next_day_skipped_brush_penalty() -> void:
	# Same blend as above (70.0), minus the skip-brush penalty (10.0) = 60.0.
	var s := GameState.new()
	s.energy = 50.0
	s.bedtime = "early"
	s.brushed_today = false
	s.start_next_day(cfg)
	assert_almost_eq(s.energy, 60.0, 0.001)


func test_next_day_carryover_makes_a_sick_morning_reachable_in_normal_play() -> void:
	# The whole point of the ruling: running the tank to empty before a late
	# night, unbrushed, must be able to wake up sick without a burrow day.
	# 0.5*0 + 0.5*35 - 10 = 7.5, well under the sick threshold (12.0).
	var s := GameState.new()
	s.energy = 0.0
	s.bedtime = "late"
	s.brushed_today = false
	s.start_next_day(cfg)
	assert_almost_eq(s.energy, 7.5, 0.001)
	assert_lt(s.energy, cfg.sick_energy_threshold, "an exhausted late night should reach sick range")


func test_next_day_carryover_keeps_the_healthy_path_healthy() -> void:
	# A normal, well-rested day should land nowhere near the sick threshold.
	# 0.5*50 + 0.5*65 = 57.5.
	var s := GameState.new()
	s.energy = 50.0
	s.bedtime = "mid"
	s.brushed_today = true
	s.start_next_day(cfg)
	assert_almost_eq(s.energy, 57.5, 0.001)
	assert_gt(
		s.energy, cfg.sick_energy_threshold, "an ordinary day should stay comfortably above sick range"
	)


func test_new_state_starts_in_the_mailroom_broke() -> void:
	var s := GameState.new()
	assert_eq(s.rank, 0)
	assert_eq(s.wallet.savings, 0)
	assert_false(s.warning)
	assert_false(s.coffee_today)
	assert_false(s.sick_today)


func test_next_day_clears_daily_flags() -> void:
	var s := GameState.new()
	s.coffee_today = true
	s.start_next_day(cfg)
	assert_false(s.coffee_today)


func test_sick_recovery_overrides_bedtime_energy() -> void:
	var s := GameState.new()
	s.sick_today = true
	s.sick_recovery = 72.0
	s.brushed_today = false
	s.bedtime = "late"
	s.start_next_day(cfg)
	assert_eq(s.energy, 72.0)
	assert_false(s.sick_today)
