class_name RankLadder

## Static evaluator run once per day close. Mutates state, returns event
## strings for the summary beats. Rank floor is the mailroom — no firing,
## ever. Demotion always re-telegraphs: warning clears on demote so the
## next drop warns again first.

const MAX_RANK := 2
const RANK_NAMES := ["mailroom", "junior", "associate"]


static func evaluate(state: GameState, cfg: BalanceConfig) -> Array[String]:
	var events: Array[String] = []
	if state.performance >= cfg.promote_threshold and state.rank < MAX_RANK:
		state.promote_streak += 1
		if state.promote_streak >= cfg.promote_sustain_days:
			state.rank += 1
			state.promote_streak = 0
			events.append("promoted")
	else:
		state.promote_streak = 0
	if state.performance < cfg.demote_threshold:
		if not state.warning:
			state.warning = true
			events.append("warned")
		elif state.rank > 0:
			state.rank -= 1
			state.warning = false
			events.append("demoted")
	elif state.warning:
		state.warning = false
		events.append("warning_cleared")
	return events
