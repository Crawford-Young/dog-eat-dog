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


## A sick day's accounting. There is no evening and so no bedtime — the schedule
## collapses to the sick beat — which left the debt frozen at whatever it was;
## frozen at the cap, the ceiling pinned energy under the sick threshold and the
## next morning built another sick day, forever. Being sick IS sleeping all day,
## so the day banks one long night, and that is the only thing able to pay debt
## down when there is no bedtime to have. The bed minute is synthesized backwards
## from sick_sleep_minutes and handed to record_night, so the wrap and both caps
## stay in exactly one place.
func record_sick_day(cfg: BalanceConfig) -> float:
	var wake := float(cfg.morning_start_minutes)
	return record_night(wake + 1440.0 - maxf(cfg.sick_sleep_minutes, 0.0), wake, cfg)


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
##
## The rung is the ceiling's clarity tier — the same tier the dog's state text
## reads — so the copy cannot say "square" while the dog looks tired, and the
## cuts move with any retune of the cap instead of drifting off it. Counting
## nights did drift: the 420 cap sits under one night of need, so "N nights
## behind" could never print and "square" covered a ceiling of ~47.
func ledger_text(slept_minutes: float, cfg: BalanceConfig) -> String:
	var whole := int(slept_minutes)
	var tonight := "%dh%02d tonight." % [whole / 60, whole % 60]
	if debt_minutes < 0.0:
		return "%s banked." % tonight
	var tier := Difficulty.clarity_tier(max_energy(cfg))
	if tier >= 4:
		return "%s square." % tonight
	if tier >= 2:
		return "%s running short." % tonight
	return "%s running on fumes." % tonight
