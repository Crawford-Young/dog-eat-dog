class_name StatEffects

## Applies a finished minigame's result to game state. Pure, fully tested.
##
## D1 (still open): the lunch score is computed but not consumed here —
## listening scores its hits, yet none of it reaches state. A later wave gives
## it a sink (reputation). Work scores got theirs in wave 2 (the rank ladder).
## Wave 3a closed the wake/brush half of D1 differently: their par times are
## gone entirely, because time IS the morning clock's now — dawdling costs
## budget, and the budget is what the drive cashes out as lateness.


static func apply(slot: String, result: Dictionary, state: GameState, cfg: BalanceConfig) -> void:
	match slot:
		"wake":
			pass  # getting up is its own reward
		"brush":
			if not result.get("skipped", false):
				state.apply_energy(cfg.selfcare_restore)
				state.brushed_today = true
		"shower":
			if not result.get("skipped", false):
				state.apply_energy(cfg.selfcare_restore)
				state.showered_today = true
		"clothes":
			pass  # mandatory; fumbles already cost clock
		"breakfast":
			if result.get("skipped", false):
				state.apply_energy(-cfg.skip_breakfast_penalty)
			else:
				state.apply_energy(lerpf(cfg.breakfast_energy_min,
						cfg.breakfast_energy_max, result.get("score", 0.0)))
		"drive":
			# game.gd stamps the morning's overrun onto the result before this
			# runs — the commute is where a blown clock is finally charged.
			var overrun: float = result.get("overrun", 0.0)
			if overrun > 0.0:
				var debit := minf(overrun * cfg.lateness_debit_per_min,
						cfg.lateness_debit_cap)
				state.performance = clampf(state.performance - debit, 0.0, 1.0)
		"coffee":
			if result.get("choice") == "buy" and state.wallet.spend(cfg.coffee_price):
				state.coffee_today = true
		"retire_offer", "warning":
			pass  # beats — flow control lives in game.gd
		"sick":
			state.sick_today = true
			state.sick_recovery = lerpf(cfg.sick_reset_min, cfg.sick_reset_max,
					clampf(result.get("score", 0.0), 0.0, 1.0))
		"work_am":
			state.record_work_score(result.score)
			state.apply_energy(-cfg.work_drain)
			if state.coffee_today:
				state.apply_energy(-cfg.coffee_crash_drain)
		"work_pm":
			state.record_work_score(result.score)
			state.apply_energy(-cfg.work_drain)
		"lunch":
			state.apply_energy(cfg.lunch_restore)
		"dinner":
			# Stub only — T8 replaces this with cooking's real per-verb score.
			# cook_energy_min (2.0) < dinner_takeout_energy (3.0) by default, which
			# would flip "cook beats takeout"; cook_energy_max preserves it as a
			# placeholder until the cooking session provides a real gain.
			state.apply_energy(cfg.dinner_takeout_energy if result.get("choice") == "takeout" else cfg.cook_energy_max)
			if result.get("choice") == "takeout":
				state.wallet.spend(cfg.takeout_price)
		"freetime":
			var games: int = result.get("games_played", 0)
			state.played_late = games > 0
			state.bedtime = derive_bedtime(games)
		"sleep":
			pass  # bedtime was already decided by the freetime loop


## Bedtime is not a choice any more — it falls out of how many "one more
## game"s happened at freetime.
static func derive_bedtime(games_played: int) -> String:
	if games_played <= 0:
		return "early"
	if games_played == 1:
		return "mid"
	return "late"


static func close_day(state: GameState, cfg: BalanceConfig) -> Dictionary:
	if state.sick_today:
		# QA ruling (issue #8): rent and kibble don't pause for a sick day —
		# being sick actively costs money, same as any other day.
		var cost := state.wallet.drain(cfg.daily_living_cost)
		var sick_events: Array[String] = ["sick_no_pay"]
		return {"pay": 0, "cost": cost, "events": sick_events}
	var pay: int = cfg.salaries[state.rank]
	# Pay lands FIRST, then the drain — the day's paycheque covers its own
	# living cost, so a working day nets exactly the margin, never a dip
	# below the pre-day balance.
	state.wallet.credit(pay)
	var cost := state.wallet.drain(cfg.daily_living_cost)
	# QA ruling (issue #10 / finding 1): rank news reads as morning-in-bed
	# news if it waits for the day-end summary — the ladder now evaluates
	# right after work_pm (game.gd), same day, at the office. A sick day has
	# no work_pm slot in its schedule (DaySchedule.build), so "sick days
	# never evaluate the ladder" holds by construction now, not a special case.
	var normal_events: Array[String] = []
	return {"pay": pay, "cost": cost, "events": normal_events}
