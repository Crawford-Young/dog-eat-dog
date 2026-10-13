class_name StatEffects

## Applies a finished minigame's result to game state. Pure, fully tested.
##
## D1 (still open): the lunch score is computed but not consumed here —
## listening scores its hits, yet none of it reaches state. A later wave gives
## it a sink (reputation). Work scores got theirs in wave 2 (the rank ladder).
## The wake/brush half of D1 has no par times: each game has its own time
## limit that fails it (see LOSS_COST_SLOTS), while the morning clock still
## cashes dawdling as the drive's lateness.

## The slots where a lost game (`failed`) pays the loss cost, on top of the
## slot's own effects. drive, work and freetime are left out on purpose: their
## miss is already charged as the lateness debit, the work-score EMA and the
## sleep ledger (user ruling, issue #17), so paying here would double it. So is
## drive_home: past home_by, its bill is the evening clock and sleep (#18). And
## coffee: a spilled cup's bill is the price, spent in its own branch. Dinner
## pays it: a walk that times out is sad kibble, with nothing else charged.
const LOSS_COST_SLOTS := ["wake", "brush", "shower", "clothes", "breakfast", "lunch", "dinner",
		"cooking"]


static func apply(slot: String, result: Dictionary, state: GameState, cfg: BalanceConfig) -> void:
	match slot:
		"wake":
			pass  # getting up is its own reward
		"brush":
			if not result.get("skipped", false):
				_restore_unless_lost(result, state, cfg)
				state.brushed_today = true
		"shower":
			if not result.get("skipped", false):
				_restore_unless_lost(result, state, cfg)
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
			# A spill (a grab off the cup) still pays the cart; money is its
			# whole cost, which is why coffee is not a LOSS_COST_SLOT.
			match result.get("choice"):
				"buy":
					if state.wallet.spend(cfg.coffee_price):
						state.coffee_today = true
				"spill":
					state.wallet.spend(cfg.coffee_price)
		"retire_offer", "warning":
			pass  # beats — flow control lives in game.gd
		"sick":
			state.sick_today = true
			state.sick_recovery = lerpf(cfg.sick_reset_min, cfg.sick_reset_max,
					clampf(result.get("score", 0.0), 0.0, 1.0))
			# A sick day has no freetime slot to record a night, so the day banks
			# its own long one. Without this the debt freezes, and a ledger at the
			# cap pins the dog under the sick threshold every morning after —
			# "sick day = exactly 1 day" depends on this line.
			state.ledger.record_sick_day(cfg)
			state.refresh_ceiling(cfg)
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
			# Takeout buys CLOCK with money — the first and only place in the
			# game where that trade exists. The morning is the inverse: skipping
			# a chore costs time there, never saves it (wave-3a invariant). A
			# walk that timed out (sad kibble) carries no choice, so it gets no
			# energy here; the loss cost below is its bill.
			if result.get("choice") == "takeout":
				state.apply_energy(cfg.dinner_takeout_energy)
				state.wallet.spend(cfg.takeout_price)
		"cooking":
			state.apply_energy(
				lerpf(cfg.cook_energy_min, cfg.cook_energy_max, result.get("score", 0.0))
			)
		"freetime":
			# game.gd stamps the band and the bed minute onto the result before
			# this runs — same shape as the overrun it stamps onto the drive.
			# StatEffects never touches a clock (wave-3a invariant).
			state.bedtime = result.get("band", "mid")
			state.ledger.record_night(
				result.get("bed_minute", float(cfg.bed_mid_line_minutes)),
				float(cfg.morning_start_minutes),
				cfg,
			)
			state.refresh_ceiling(cfg)
		"sleep":
			pass  # the night was recorded at freetime; this beat only reads it out
	# Charged last, so a restore that hits the ceiling cannot swallow it.
	if result.get("failed", false) and slot in LOSS_COST_SLOTS:
		state.performance = clampf(state.performance - cfg.fail_performance_cost, 0.0, 1.0)
		state.apply_energy(-cfg.fail_energy_cost)


## A lost brush or shower still counts as done (no skip penalty tomorrow), but
## forfeits its restore, so the loss cost is the whole net (user revision, #17).
static func _restore_unless_lost(result: Dictionary, state: GameState, cfg: BalanceConfig) -> void:
	if not result.get("failed", false):
		state.apply_energy(cfg.selfcare_restore)


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
	# news if it waits for the day-end summary — the ladder evaluates
	# right after work_pm (game.gd), same day, at the office. A sick day has
	# no work_pm slot in its schedule (DaySchedule.build), so "sick days
	# never evaluate the ladder" holds by construction, not as a special case.
	var normal_events: Array[String] = []
	return {"pay": pay, "cost": cost, "events": normal_events}
