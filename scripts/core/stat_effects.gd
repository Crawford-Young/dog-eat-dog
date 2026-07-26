class_name StatEffects

## Applies a finished minigame's result to game state. Pure, fully tested.
##
## D1 (deferred to wave 3): wake, brush and lunch scores are computed but not
## consumed here — wake/brush pace against `wake_par_time`/`brush_par_time` and
## listening scores its hits, yet none of it reaches state. Wave 3 gives them a
## sink (reputation). Work scores got their sink this wave (the rank ladder).


static func apply(slot: String, result: Dictionary, state: GameState, cfg: BalanceConfig) -> void:
	match slot:
		"wake":
			pass  # getting up is its own reward
		"brush":
			if not result.get("skipped", false):
				state.apply_energy(cfg.selfcare_restore)
				state.brushed_today = true
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
			var gain := cfg.dinner_cook_energy if result.get("choice") == "cook" \
					else cfg.dinner_takeout_energy
			state.apply_energy(gain)
			if result.get("choice") == "takeout":
				state.wallet.spend(cfg.takeout_price)
		"freetime":
			var games: int = result.get("games_played", 0)
			state.apply_energy(-cfg.late_game_drain * games)
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
	return {"pay": pay, "cost": cost, "events": RankLadder.evaluate(state, cfg)}
