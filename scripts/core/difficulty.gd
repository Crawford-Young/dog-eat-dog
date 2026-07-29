class_name Difficulty

## Maps current energy (0-100) + BalanceConfig to per-minigame params.
## deficit = 0.0 at full energy, 1.0 at empty. All knobs lerp on deficit.


static func _deficit(energy: float) -> float:
	return 1.0 - clampf(energy, 0.0, 100.0) / 100.0


static func clarity_tier(energy: float) -> int:
	if energy >= 80.0:
		return 4
	if energy >= 60.0:
		return 3
	if energy >= 40.0:
		return 2
	if energy >= 20.0:
		return 1
	return 0


static func wake_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"mash_target": roundi(lerpf(cfg.wake_mash_base, cfg.wake_mash_max, d)),
		"decay_per_sec": lerpf(0.0, cfg.wake_decay_max, d),
	}


static func brush_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"strokes_required": roundi(lerpf(cfg.brush_strokes_base, cfg.brush_strokes_max, d)),
		"amplitude": cfg.brush_amplitude,
	}


static func typing_params(energy: float, cfg: BalanceConfig, boost_tiers: int = 0, rank: int = 0) -> Dictionary:
	return {
		"tier": clampi(clarity_tier(energy) + boost_tiers, 0, 4),
		"wrong_cap": cfg.typing_wrong_cap,
		"shift_time": cfg.typing_shift_time,
		"par_units": cfg.typing_par_units[clampi(rank, 0, cfg.typing_par_units.size() - 1)],
	}


static func shower_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"spots": roundi(lerpf(cfg.shower_spots_base, cfg.shower_spots_max, d)),
		"revolutions": cfg.shower_revolutions,
		"min_radius": cfg.shower_min_radius,
	}


static func dress_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {"fumble_chance": lerpf(cfg.dress_fumble_base, cfg.dress_fumble_max, d)}


static func breakfast_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"window": lerpf(cfg.breakfast_window_base, cfg.breakfast_window_min, d),
		"speed": cfg.breakfast_beat_speed,
		"beats": cfg.breakfast_beats,
	}


static func drive_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"length": cfg.drive_length,
		"top_speed": cfg.drive_top_speed,
		"accel": cfg.drive_accel,
		"pin_gap": cfg.drive_pin_gap,
		"block_margin": cfg.drive_block_margin,
		"switch_lag": lerpf(cfg.drive_switch_lag_base, cfg.drive_switch_lag_max, d),
		"car_min_gap": cfg.drive_car_min_gap,
		"day_speed_min": cfg.drive_day_speed_min,
		"day_speed_max": cfg.drive_day_speed_max,
		"wave_speed_jitter": cfg.drive_wave_speed_jitter,
		"car_speed_jitter": cfg.drive_car_speed_jitter,
		"blocked_wave_chance": cfg.drive_blocked_wave_chance,
		# Traffic is generated in whole waves, so the car count is always a
		# whole number of walls — the wave count is what the deficit scales.
		"car_count": roundi(lerpf(cfg.drive_waves_base, cfg.drive_waves_max, d))
				* LaneSim.CARS_PER_WAVE,
	}


static func is_sick_morning(energy: float, cfg: BalanceConfig) -> bool:
	return energy < cfg.sick_energy_threshold


static func listening_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"window": lerpf(cfg.listening_window_base, cfg.listening_window_min, d),
		"tier": clarity_tier(energy),
		"text_speed": lerpf(cfg.listening_text_speed_base, cfg.listening_text_speed_max, d),
	}


static func temptation_params(energy: float, cfg: BalanceConfig, played_late: bool) -> Dictionary:
	var d := _deficit(energy)
	var pull := lerpf(cfg.temptation_pull_base, cfg.temptation_pull_max, d)
	if played_late:
		pull += cfg.temptation_habit_bonus
	return {
		"pull_strength": pull,
		"dwell_time": cfg.temptation_dwell_time,
		"pull_growth": cfg.temptation_pull_growth,
		"pull_ceiling": cfg.temptation_pull_ceiling,
	}
