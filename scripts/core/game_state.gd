class_name GameState
extends RefCounted

var energy: float = 65.0
var performance: float = 0.5
var day: int = 1
var brushed_today: bool = false
var played_late: bool = false
var bedtime: String = "mid"
var wallet := Wallet.new()
var rank: int = 0
var warning: bool = false
var promote_streak: int = 0
var coffee_today: bool = false
var sick_today: bool = false
var sick_recovery: float = 65.0


func apply_energy(delta: float) -> void:
	energy = clampf(energy + delta, 0.0, 100.0)


func record_work_score(score: float) -> void:
	performance = clampf(performance * 0.7 + score * 0.3, 0.0, 1.0)


func start_next_day(cfg: BalanceConfig) -> void:
	day += 1
	if sick_today:
		# Sick recovery replaces the bedtime formula: the burrow's mash score
		# already decided tomorrow's energy. No brush penalty on a sick day.
		energy = sick_recovery
	else:
		# Wave-2 QA ruling (issue #5): sleep is a blend of leftover energy and
		# the bedtime target, not a full reset — exhaustion carries over.
		var leftover := energy
		energy = cfg.energy_carry_weight * leftover \
				+ (1.0 - cfg.energy_carry_weight) * cfg.sleep_energy[bedtime]
		if not brushed_today:
			energy -= cfg.skip_brush_penalty
	energy = clampf(energy, 0.0, 100.0)
	brushed_today = false
	coffee_today = false
	sick_today = false
