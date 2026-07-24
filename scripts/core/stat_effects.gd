class_name StatEffects

## Applies a finished minigame's result to game state. Pure, fully tested.


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
			if result.get("choice") == "game":
				state.apply_energy(-cfg.late_game_drain)
				state.played_late = true
			else:
				state.played_late = false
		"sleep":
			state.bedtime = result.get("choice", "mid")
