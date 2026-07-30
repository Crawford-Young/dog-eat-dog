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
	s.showered_today = true
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
	s.showered_today = true
	s.start_next_day(cfg)
	assert_almost_eq(s.energy, 60.0, 0.001)


func test_skip_shower_penalty_next_morning() -> void:
	var a := GameState.new()
	var b := GameState.new()
	for s in [a, b]:
		s.energy = 60.0
		s.bedtime = "mid"
		s.brushed_today = true
	a.showered_today = true
	b.showered_today = false
	a.start_next_day(cfg)
	b.start_next_day(cfg)
	assert_almost_eq(a.energy - b.energy, cfg.skip_shower_penalty, 0.001)


func test_showered_resets_daily() -> void:
	var s := GameState.new()
	s.showered_today = true
	s.brushed_today = true
	s.start_next_day(cfg)
	assert_false(s.showered_today)


func test_next_day_carryover_makes_a_sick_morning_reachable_in_normal_play() -> void:
	# The whole point of the ruling: running the tank to empty before a late
	# night, unbrushed, must be able to wake up sick without a burrow day.
	# 0.5*0 + 0.5*35 - 10 = 7.5, well under the sick threshold (12.0).
	var s := GameState.new()
	s.energy = 0.0
	s.bedtime = "late"
	s.brushed_today = false
	s.showered_today = true
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
	s.showered_today = true
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
	# The burrow's mash score IS tomorrow's energy — neither the skipped brush
	# nor the skipped shower is charged on a day spent under a blanket.
	var s := GameState.new()
	s.sick_today = true
	s.sick_recovery = 72.0
	s.brushed_today = false
	s.showered_today = false
	s.bedtime = "late"
	s.start_next_day(cfg)
	assert_eq(s.energy, 72.0)
	assert_false(s.sick_today)


func test_the_ceiling_clamps_apply_energy() -> void:
	# Load-bearing. Without this clamp, coffee or breakfast refills a
	# sleep-deprived dog back to full and the debt has no daytime presence at
	# all — it would only ever show up for one frame at dawn.
	var cfg := BalanceConfig.new()
	var s := GameState.new()
	s.ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	s.refresh_ceiling(cfg)
	s.apply_energy(500.0)
	assert_eq(s.energy, cfg.sleep_ceiling_min, "no meal outruns a sleep debt")


func test_the_ceiling_clamps_the_overnight_blend() -> void:
	var cfg := BalanceConfig.new()
	var s := GameState.new()
	s.bedtime = "early"
	s.energy = 90.0
	s.brushed_today = true
	s.showered_today = true
	s.ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	s.refresh_ceiling(cfg)
	s.start_next_day(cfg)
	assert_eq(s.energy, cfg.sleep_ceiling_min, "an early night cannot outrun the week")


func test_no_debt_leaves_the_old_behaviour_untouched() -> void:
	# 0.5*50 + 0.5*90 = 70.0 — the wave-2 carry blend, unchanged.
	var cfg := BalanceConfig.new()
	var s := GameState.new()
	s.bedtime = "early"
	s.energy = 50.0
	s.brushed_today = true
	s.showered_today = true
	s.start_next_day(cfg)
	assert_eq(s.energy, 70.0)
	assert_eq(s.energy_ceiling, 100.0)
