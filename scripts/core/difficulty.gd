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
		"par_time": cfg.wake_par_time,
	}


static func brush_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"strokes_required": roundi(lerpf(cfg.brush_strokes_base, cfg.brush_strokes_max, d)),
		"amplitude": cfg.brush_amplitude,
		"par_time": cfg.brush_par_time,
	}


static func typing_params(energy: float, cfg: BalanceConfig) -> Dictionary:
	var d := _deficit(energy)
	return {
		"tier": clarity_tier(energy),
		"error_tolerance": lerpf(cfg.typing_error_tolerance_base, cfg.typing_error_tolerance_min, d),
		"wrong_cap": cfg.typing_wrong_cap,
	}


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
