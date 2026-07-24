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
	var s := GameState.new()
	s.bedtime = "early"
	s.brushed_today = true
	s.start_next_day(cfg)
	assert_eq(s.day, 2)
	assert_eq(s.energy, cfg.sleep_energy["early"])
	assert_false(s.brushed_today)


func test_next_day_skipped_brush_penalty() -> void:
	var s := GameState.new()
	s.bedtime = "early"
	s.brushed_today = false
	s.start_next_day(cfg)
	assert_eq(s.energy, cfg.sleep_energy["early"] - cfg.skip_brush_penalty)
