extends GutTest

var cfg: BalanceConfig


func before_each() -> void:
	cfg = BalanceConfig.new()


func test_clarity_tier_boundaries() -> void:
	assert_eq(Difficulty.clarity_tier(100.0), 4)
	assert_eq(Difficulty.clarity_tier(80.0), 4)
	assert_eq(Difficulty.clarity_tier(79.9), 3)
	assert_eq(Difficulty.clarity_tier(60.0), 3)
	assert_eq(Difficulty.clarity_tier(40.0), 2)
	assert_eq(Difficulty.clarity_tier(20.0), 1)
	assert_eq(Difficulty.clarity_tier(0.0), 0)


func test_wake_params_full_energy_is_base() -> void:
	var p := Difficulty.wake_params(100.0, cfg)
	assert_eq(p.mash_target, cfg.wake_mash_base)
	assert_almost_eq(p.decay_per_sec, 0.0, 0.001)


func test_wake_params_zero_energy_is_max() -> void:
	var p := Difficulty.wake_params(0.0, cfg)
	assert_eq(p.mash_target, cfg.wake_mash_max)
	assert_almost_eq(p.decay_per_sec, cfg.wake_decay_max, 0.001)


func test_typing_params_scale() -> void:
	assert_eq(Difficulty.typing_params(100.0, cfg).tier, 4)
	assert_eq(Difficulty.typing_params(0.0, cfg).tier, 0)
	assert_almost_eq(Difficulty.typing_params(100.0, cfg).error_tolerance, cfg.typing_error_tolerance_base, 0.001)


func test_temptation_pull_grows_with_habit() -> void:
	var sober := Difficulty.temptation_params(50.0, cfg, false)
	var hooked := Difficulty.temptation_params(50.0, cfg, true)
	assert_gt(hooked.pull_strength, sober.pull_strength)
