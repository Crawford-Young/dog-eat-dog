class_name StatEffects

## Applies a finished minigame's result to game state. Pure, fully tested.
##
## D1 (deferred to wave 2): wake, brush and lunch scores are computed but not
## consumed here — wake/brush pace against `wake_par_time`/`brush_par_time` and
## listening scores its hits, yet none of it reaches state. Wave 2 gives them a
## sink (reputation). Only work score moves the needle in wave 1.


static func apply(slot: String, result: Dictionary, state: GameState, cfg: BalanceConfig) -> void:
	match slot:
		"wake":
			pass  # getting up is its own reward
		"brush":
			if not result.get("skipped", false):
				state.apply_energy(cfg.selfcare_restore)
				state.brushed_today = true
		"work_am", "work_pm":
			state.record_work_score(result.score)
			state.apply_energy(-cfg.work_drain)
		"lunch":
			state.apply_energy(cfg.lunch_restore)
		"dinner":
			var gain := cfg.dinner_cook_energy if result.get("choice") == "cook" \
					else cfg.dinner_takeout_energy
			state.apply_energy(gain)
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
