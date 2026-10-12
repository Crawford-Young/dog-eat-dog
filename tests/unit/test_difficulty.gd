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


func test_brush_params_full_energy_is_base() -> void:
	var p := Difficulty.brush_params(100.0, cfg)
	assert_eq(p.strokes_required, cfg.brush_strokes_base)
	assert_almost_eq(p.amplitude, cfg.brush_amplitude, 0.001)


func test_brush_params_demand_more_strokes_as_energy_drops() -> void:
	var fresh := Difficulty.brush_params(100.0, cfg)
	var tired := Difficulty.brush_params(0.0, cfg)
	assert_gt(tired.strokes_required, fresh.strokes_required)
	assert_eq(tired.strokes_required, cfg.brush_strokes_max)


func test_listening_window_shrinks_as_energy_drops() -> void:
	var fresh := Difficulty.listening_params(100.0, cfg)
	var tired := Difficulty.listening_params(0.0, cfg)
	assert_almost_eq(fresh.window, cfg.listening_window_base, 0.001)
	assert_almost_eq(tired.window, cfg.listening_window_min, 0.001)
	assert_lt(tired.window, fresh.window)


func test_listening_params_carry_tier_and_text_speed() -> void:
	var p := Difficulty.listening_params(100.0, cfg)
	assert_eq(p.tier, 4)
	assert_eq(Difficulty.listening_params(0.0, cfg).tier, 0)
	assert_almost_eq(p.text_speed, cfg.listening_text_speed_base, 0.001)


func test_listening_speech_speeds_up_when_tired() -> void:
	assert_gt(
		Difficulty.listening_params(60.0, cfg).text_speed,
		Difficulty.listening_params(100.0, cfg).text_speed,
	)
	assert_almost_eq(
		Difficulty.listening_params(0.0, cfg).text_speed,
		cfg.listening_text_speed_max,
		0.001,
	)


func test_coworker_speech_finishes_inside_its_own_window() -> void:
	var listening := load("res://scripts/minigames/listening_minigame.gd")
	var longest := 0
	for beat in listening.BEATS:
		longest = maxi(longest, (beat.text as String).length())
	# tier 3 (energy 60) is the lowest energy that still renders text, not emoji;
	# sweep the whole text-rendering range since both window and speed move
	# together as energy drops
	for energy in [60, 70, 80, 90, 100]:
		var params := Difficulty.listening_params(float(energy), cfg)
		var reveal_time: float = longest / params.text_speed
		assert_lt(reveal_time, params.window, "the longest line must land before the window shuts")


func test_typing_params_scale() -> void:
	assert_eq(Difficulty.typing_params(100.0, cfg).tier, 4)
	assert_eq(Difficulty.typing_params(0.0, cfg).tier, 0)


func test_typing_params_carry_the_wrong_buffer_cap() -> void:
	assert_eq(Difficulty.typing_params(50.0, cfg).wrong_cap, cfg.typing_wrong_cap)


func test_the_temptation_pull_scales_with_sleep_debt() -> void:
	# The habit spiral has depth: a late night makes the next one harder to
	# resist, and five late nights harder still.
	var cfg := BalanceConfig.new()
	var rested := Difficulty.temptation_params(65.0, cfg, 0.0)
	var behind := Difficulty.temptation_params(65.0, cfg, cfg.sleep_debt_cap_minutes * 0.5)
	var wrecked := Difficulty.temptation_params(65.0, cfg, cfg.sleep_debt_cap_minutes)
	assert_lt(rested.pull_strength, behind.pull_strength)
	assert_lt(behind.pull_strength, wrecked.pull_strength)
	assert_almost_eq(
		wrecked.pull_strength - rested.pull_strength, cfg.temptation_habit_bonus, 0.001,
		"a maxed debt adds exactly the full temptation_habit_bonus",
	)


func test_a_banked_surplus_pulls_no_harder_than_square() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(
		Difficulty.temptation_params(65.0, cfg, -240.0).pull_strength,
		Difficulty.temptation_params(65.0, cfg, 0.0).pull_strength,
	)


func test_temptation_params_carry_the_loop_tunables() -> void:
	var p := Difficulty.temptation_params(50.0, cfg, 0.0)
	assert_almost_eq(p.dwell_time, cfg.temptation_dwell_time, 0.001)
	assert_almost_eq(p.pull_growth, cfg.temptation_pull_growth, 0.001)
	assert_almost_eq(p.pull_ceiling, cfg.temptation_pull_ceiling, 0.001)


func test_temptation_ceiling_clears_the_worst_starting_pull() -> void:
	# the ceiling has to sit above the hardest pull the energy lerp + habit
	# bonus can hand out, or a tired repeat offender starts already capped
	var worst := Difficulty.temptation_params(0.0, cfg, cfg.sleep_debt_cap_minutes)
	assert_gt(cfg.temptation_pull_ceiling, worst.pull_strength)


func test_coffee_boosts_typing_clarity_two_tiers() -> void:
	var p := Difficulty.typing_params(30.0, cfg, cfg.coffee_buff_tiers)
	assert_eq(p.tier, Difficulty.clarity_tier(30.0) + 2)


func test_coffee_boost_caps_at_top_tier() -> void:
	var p := Difficulty.typing_params(90.0, cfg, cfg.coffee_buff_tiers)
	assert_eq(p.tier, 4)


func test_no_boost_matches_wave_one_behavior() -> void:
	assert_eq(Difficulty.typing_params(50.0, cfg).tier, Difficulty.clarity_tier(50.0))


func test_sick_morning_below_threshold_only() -> void:
	assert_true(Difficulty.is_sick_morning(cfg.sick_energy_threshold - 0.1, cfg))
	assert_false(Difficulty.is_sick_morning(cfg.sick_energy_threshold, cfg))


func test_shower_params_scale_with_deficit() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(Difficulty.shower_params(100.0, cfg).spots, cfg.shower_spots_base)
	assert_eq(Difficulty.shower_params(0.0, cfg).spots, cfg.shower_spots_max)
	assert_almost_eq(Difficulty.shower_params(50.0, cfg).revolutions, cfg.shower_revolutions, 0.001)


func test_dress_fumble_scales_with_deficit() -> void:
	var cfg := BalanceConfig.new()
	assert_almost_eq(Difficulty.dress_params(100.0, cfg).fumble_chance, cfg.dress_fumble_base, 0.001)
	assert_almost_eq(Difficulty.dress_params(0.0, cfg).fumble_chance, cfg.dress_fumble_max, 0.001)


func test_breakfast_window_narrows_with_deficit() -> void:
	var cfg := BalanceConfig.new()
	assert_almost_eq(Difficulty.breakfast_params(100.0, cfg).window, cfg.breakfast_window_base, 0.001)
	assert_almost_eq(Difficulty.breakfast_params(0.0, cfg).window, cfg.breakfast_window_min, 0.001)
	assert_eq(Difficulty.breakfast_params(50.0, cfg).beats, cfg.breakfast_beats)


func test_cooking_rhythm_window_narrows_with_deficit_and_carries_the_beat() -> void:
	var cfg := BalanceConfig.new()
	assert_almost_eq(Difficulty.cooking_params(100.0, cfg).window, cfg.cook_window_base, 0.001)
	assert_almost_eq(Difficulty.cooking_params(0.0, cfg).window, cfg.cook_window_min, 0.001)
	assert_almost_eq(Difficulty.cooking_params(100.0, cfg).beat_speed, cfg.cook_beat_speed, 0.001)
	assert_almost_eq(Difficulty.cooking_params(0.0, cfg).beat_speed, cfg.cook_beat_speed, 0.001)


func test_drive_traffic_and_lag_scale_with_deficit() -> void:
	var cfg := BalanceConfig.new()
	var fresh := Difficulty.drive_params(100.0, cfg)
	var wrecked := Difficulty.drive_params(0.0, cfg)
	# The commute scales in whole waves — a wave is one car in every lane but one.
	assert_eq(fresh.car_count, cfg.drive_waves_base * LaneSim.CARS_PER_WAVE)
	assert_eq(wrecked.car_count, cfg.drive_waves_max * LaneSim.CARS_PER_WAVE)
	assert_gt(wrecked.car_count, fresh.car_count)
	assert_almost_eq(fresh.switch_lag, cfg.drive_switch_lag_base, 0.001)
	assert_almost_eq(wrecked.switch_lag, cfg.drive_switch_lag_max, 0.001)
	assert_almost_eq(fresh.length, cfg.drive_length, 0.001)
	assert_almost_eq(fresh.car_min_gap, cfg.drive_car_min_gap, 0.001)


func test_drive_params_carries_the_traffic_randomness_tunables() -> void:
	var cfg := BalanceConfig.new()
	var p := Difficulty.drive_params(90.0, cfg)
	assert_eq(p.day_speed_min, cfg.drive_day_speed_min)
	assert_eq(p.day_speed_max, cfg.drive_day_speed_max)
	assert_eq(p.wave_speed_jitter, cfg.drive_wave_speed_jitter)
	assert_eq(p.car_speed_jitter, cfg.drive_car_speed_jitter)
	assert_eq(p.blocked_wave_chance, cfg.drive_blocked_wave_chance)


func test_the_drive_home_is_the_morning_road_but_shorter() -> void:
	var cfg := BalanceConfig.new()
	var morning := Difficulty.drive_params(65.0, cfg)
	var evening := Difficulty.drive_home_params(65.0, cfg)
	assert_lt(evening.length, morning.length)
	assert_lt(evening.route_miles, morning.route_miles)
	assert_lt(evening.car_count, morning.car_count, "fewer walls on a shorter road")
	assert_eq(evening.top_speed, morning.top_speed, "same car, same road rules")
	assert_eq(evening.keys().size(), morning.keys().size(), "and the same param contract")


func test_typing_params_carry_shift_and_rank_par() -> void:
	var cfg := BalanceConfig.new()
	var p := Difficulty.typing_params(80.0, cfg, 0, 2)
	assert_almost_eq(p.shift_time, cfg.typing_shift_time, 0.001)
	assert_eq(p.par_units, cfg.typing_par_units[2])
	assert_false(p.has("error_tolerance"))


func test_typing_par_clamps_rank_to_table() -> void:
	var cfg := BalanceConfig.new()
	assert_eq(Difficulty.typing_params(80.0, cfg, 0, 99).par_units, cfg.typing_par_units[2])


func test_wake_and_brush_params_have_no_par_time() -> void:
	var cfg := BalanceConfig.new()
	assert_false(Difficulty.wake_params(50.0, cfg).has("par_time"))
	assert_false(Difficulty.brush_params(50.0, cfg).has("par_time"))
