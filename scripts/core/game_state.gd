class_name GameState
extends RefCounted

var energy: float = 65.0
var performance: float = 0.5
var day: int = 1
var brushed_today: bool = false
var played_late: bool = false
var bedtime: String = "mid"


func apply_energy(delta: float) -> void:
	energy = clampf(energy + delta, 0.0, 100.0)


func record_work_score(score: float) -> void:
	performance = clampf(performance * 0.7 + score * 0.3, 0.0, 1.0)


func start_next_day(cfg: BalanceConfig) -> void:
	day += 1
	energy = cfg.sleep_energy[bedtime]
	if not brushed_today:
		energy -= cfg.skip_brush_penalty
	energy = clampf(energy, 0.0, 100.0)
	brushed_today = false
