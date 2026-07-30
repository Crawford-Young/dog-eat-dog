class_name SleepLedger
extends RefCounted

## The evening's memory. Wave-2 energy carryover is one night deep —
## energy_carry_weight blends yesterday's leftover with tonight's refill and
## that is the entire history, so a week of late nights costs exactly what one
## costs. This class is what makes the week cost more: every night's shortfall
## accrues, every long night pays some back, and the balance sets a ceiling on
## how awake the dog can be at all.
##
## Pure and scene-free, like DayClock and Wallet. game.gd stamps the bed minute
## onto the freetime result and StatEffects records the night — nothing else
## writes here, and NOTHING reads debt_minutes to apply a penalty directly. The
## ceiling is debt's only consequence path (wave-3b invariant).

## Minutes of sleep owed. Positive is debt, negative is banked surplus.
var debt_minutes: float = 0.0


## One night's accounting. Both minutes are absolute from midnight, and the
## night CROSSES midnight, so the wrap is mandatory rather than defensive: a
## 23:41 bedtime is minute 1421 and a 7:00 wake is minute 420, and 420 - 1421
## is negative for every late night — which is exactly the band this whole
## mechanic exists to punish. Returns the minutes actually slept, which the
## sleep beat prints.
func record_night(bed_minute: float, wake_minute: float, cfg: BalanceConfig) -> float:
	var slept := maxf(wake_minute + 1440.0 - bed_minute, 0.0)
	debt_minutes = clampf(
		debt_minutes + cfg.sleep_need_minutes - slept,
		-maxf(cfg.sleep_bank_cap_minutes, 0.0),
		maxf(cfg.sleep_debt_cap_minutes, 0.0),
	)
	return slept


## The ceiling debt puts on energy. A banked surplus buys no headroom above
## 100 — it buys the ABSENCE of a ceiling, which is already the best case.
func max_energy(cfg: BalanceConfig) -> float:
	if debt_minutes <= 0.0:
		return 100.0
	var t := clampf(debt_minutes / maxf(cfg.sleep_debt_cap_minutes, 1.0), 0.0, 1.0)
	return lerpf(100.0, cfg.sleep_ceiling_min, t)


## The one line the sleep beat prints, once a night. Debt is measured in
## clock-minutes and the game already prints minutes, so this does not touch
## the "energy is never shown as a number" rule — a persistent debt gauge
## would, which is why there is exactly one of these and it is not in the HUD.
func ledger_text(slept_minutes: float, cfg: BalanceConfig) -> String:
	var whole := int(slept_minutes)
	var tonight := "%dh%02d tonight." % [whole / 60, whole % 60]
	var half_night := cfg.sleep_need_minutes * 0.5
	if debt_minutes <= -half_night:
		return "%s banking it." % tonight
	if debt_minutes < half_night:
		return "%s square." % tonight
	var nights := int(round(debt_minutes / maxf(cfg.sleep_need_minutes, 1.0)))
	if nights <= 1:
		return "%s a night behind." % tonight
	return "%s %d nights behind." % [tonight, nights]
