extends GutTest

const Cfg := preload("res://scripts/core/balance_config.gd")


func _state(perf: float, rank: int = 0, warning: bool = false, streak: int = 0) -> GameState:
	var s := GameState.new()
	s.performance = perf
	s.rank = rank
	s.warning = warning
	s.promote_streak = streak
	return s


func test_high_performance_builds_streak_quietly() -> void:
	var s := _state(0.8)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), [])
	assert_eq(s.promote_streak, 1)
	assert_eq(s.rank, 0)


func test_sustained_performance_promotes_on_day_three() -> void:
	var s := _state(0.8, 0, false, 2)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), ["promoted"])
	assert_eq(s.rank, 1)
	assert_eq(s.promote_streak, 0)


func test_streak_breaks_on_an_off_day() -> void:
	var s := _state(0.5, 0, false, 2)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), [])
	assert_eq(s.promote_streak, 0)


func test_no_promotion_past_associate_this_wave() -> void:
	var s := _state(0.9, 2, false, 99)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), [])
	assert_eq(s.rank, 2)


func test_low_performance_warns_first() -> void:
	var s := _state(0.1, 1)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), ["warned"])
	assert_true(s.warning)
	assert_eq(s.rank, 1)


func test_still_low_next_day_demotes_and_retelegraphs() -> void:
	var s := _state(0.1, 1, true)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), ["demoted"])
	assert_eq(s.rank, 0)
	assert_false(s.warning)


func test_mailroom_is_the_floor_never_fired() -> void:
	var s := _state(0.1, 0, true)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), [])
	assert_eq(s.rank, 0)
	assert_true(s.warning)


func test_recovery_clears_the_warning() -> void:
	var s := _state(0.5, 1, true)
	assert_eq(RankLadder.evaluate(s, Cfg.new()), ["warning_cleared"])
	assert_false(s.warning)


func test_boundary_exactly_at_thresholds() -> void:
	# >= promotes-side, < demotes-side: exactly 0.7 counts toward streak,
	# exactly 0.25 is safe.
	var promote := _state(0.7, 0, false, 2)
	assert_eq(RankLadder.evaluate(promote, Cfg.new()), ["promoted"])
	var safe := _state(0.25, 1, true)
	assert_eq(RankLadder.evaluate(safe, Cfg.new()), ["warning_cleared"])
