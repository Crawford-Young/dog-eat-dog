class_name GameState
extends RefCounted

var energy: float = 65.0
var performance: float = 0.5
var day: int = 1
var brushed_today: bool = false
var showered_today: bool = false
var bedtime: String = "mid"
var wallet := Wallet.new()
var ledger := SleepLedger.new()
## Cached from ledger.max_energy(cfg) — a DERIVED value, refreshed whenever the
## ledger moves. apply_energy needs it every frame and has no cfg to hand, and
## threading cfg through every caller would put a resource in every minigame's
## reach. Nothing else may write it.
var energy_ceiling: float = 100.0
var rank: int = 0
var warning: bool = false
var promote_streak: int = 0
var coffee_today: bool = false
var snack_today: bool = false
var sick_today: bool = false
var sick_recovery: float = 65.0


func apply_energy(delta: float) -> void:
	energy = clampf(energy + delta, 0.0, energy_ceiling)


func record_work_score(score: float) -> void:
	performance = clampf(performance * 0.7 + score * 0.3, 0.0, 1.0)


## Recomputes the ceiling and pulls current energy down under it. Called
## wherever the ledger moves — StatEffects at bedtime, start_next_day at dawn.
func refresh_ceiling(cfg: BalanceConfig) -> void:
	energy_ceiling = ledger.max_energy(cfg)
	energy = clampf(energy, 0.0, energy_ceiling)


func start_next_day(cfg: BalanceConfig) -> void:
	day += 1
	refresh_ceiling(cfg)
	if sick_today:
		# Sick recovery replaces the bedtime formula: the burrow's mash score
		# already decided tomorrow's energy. No brush or shower penalty on a
		# sick day — the schedule never offered either.
		energy = sick_recovery
	else:
		# Wave-2 QA ruling (issue #5): sleep is a blend of leftover energy and
		# the bedtime target, not a full reset — exhaustion carries over.
		var leftover := energy
		energy = cfg.energy_carry_weight * leftover \
				+ (1.0 - cfg.energy_carry_weight) * cfg.sleep_energy[bedtime]
		if not brushed_today:
			energy -= cfg.skip_brush_penalty
		if not showered_today:
			energy -= cfg.skip_shower_penalty
	energy = clampf(energy, 0.0, energy_ceiling)
	brushed_today = false
	showered_today = false
	coffee_today = false
	snack_today = false
	sick_today = false
