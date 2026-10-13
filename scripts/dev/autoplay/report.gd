extends RefCounted

## Turns a run's raw tallies into the markdown report and the JSON dump.
## Pure: no engine state, so the same tallies always print the same bytes.

const Profiles := preload("res://scripts/dev/autoplay/profiles.gd")

## Report order: the day's slots as they run, out-of-band hosts beside the
## slot they interrupt.
const SLOT_ORDER: Array[String] = [
	"wake", "retire_offer", "sick", "brush", "shower", "clothes", "breakfast",
	"drive", "late_arrival", "warning", "coffee", "work_am", "lunch", "work_pm",
	"rank_news", "drive_home", "dinner", "cooking", "freetime", "sleep",
]
## Hosted by game.gd outside the schedule's slot walk.
const OUT_OF_BAND: Array[String] = ["late_arrival", "rank_news", "cooking"]


static func percentile(sorted: Array, fraction: float) -> float:
	var rank := ceili(fraction * sorted.size())
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


static func median(sorted: Array) -> float:
	var n := sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0


static func slot_stats(seconds: Array) -> Dictionary:
	var sorted := seconds.duplicate()
	sorted.sort()
	return {
		"n": sorted.size(),
		"median": median(sorted),
		"p90": percentile(sorted, 0.9),
		"max": sorted[-1],
	}


## `t` is the runner's tally dictionary; see autoplay.gd for its keys.
static func markdown(t: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("## autoplay: profile %s, seed %d, days %d" % [t.profile, t.seed, t.days])
	lines.append("")
	lines.append("Policy:")
	for row in Profiles.policy_rows(Profiles.PROFILES[t.profile]):
		lines.append("- %s" % row)
	lines.append("")
	lines.append("| slot | n | median s | p90 s | max s | median score | misses |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|")
	var misses: Dictionary = t.get("misses", {})
	for slot in _ordered_slots(t.seconds):
		var s := slot_stats(t.seconds[slot])
		var label: String = slot + (" (out-of-band)" if slot in OUT_OF_BAND else "")
		lines.append("| %s | %d | %.2f | %.2f | %.2f | %s | %d |" % [
			label, s.n, s.median, s.p90, s.max, _score_text(t.scores.get(slot, [])),
			misses.get(slot, 0),
		])
	lines.append("")
	var overruns: Array = t.overruns.duplicate()
	overruns.sort()
	var late := "%d" % overruns.size()
	if not overruns.is_empty():
		late += " (overrun minutes: total %.1f, median %.1f, max %.1f)" % [
			_sum(overruns), median(overruns), overruns[-1],
		]
	lines.append("- late arrivals: %s" % late)
	lines.append("- late-band nights: %d / %d" % [t.late_band_nights, t.nights])
	lines.append("- running-on-fumes nights: %d / %d" % [t.fumes_nights, t.nights])
	lines.append("- sick days: %d" % t.sick_days)
	lines.append("- retirement: %s" % (
		"day %d" % t.retired_day if t.retired_day > 0 else "not reached in %d" % t.days
	))
	lines.append("- final: day %d, rank %s, savings %d / %d" % [
		t.final_day, t.final_rank, t.final_savings, t.retirement_target,
	])
	lines.append("- chores skipped: %s" % _skips_text(t.skips))
	lines.append("- free-time games played: %d" % t.freetime_games)
	lines.append("- simulated: %d frames (%.1f s)" % [t.frames, t.frames / 60.0])
	lines.append("- wall time: %.1f s" % t.wall_seconds)
	return "\n".join(lines)


static func json(t: Dictionary) -> String:
	var slots := {}
	for slot in _ordered_slots(t.seconds):
		slots[slot] = slot_stats(t.seconds[slot])
	var out := t.duplicate(true)
	out["slots"] = slots
	return JSON.stringify(out, "  ", false)


static func _ordered_slots(seconds: Dictionary) -> Array[String]:
	var ordered: Array[String] = []
	for slot in SLOT_ORDER:
		if seconds.has(slot):
			ordered.append(slot)
	var unknown: Array = seconds.keys().filter(func(k: String) -> bool: return k not in SLOT_ORDER)
	unknown.sort()
	for slot in unknown:
		ordered.append(slot)
	return ordered


static func _score_text(scores: Array) -> String:
	if scores.is_empty():
		return "-"
	var sorted := scores.duplicate()
	sorted.sort()
	return "%.2f" % median(sorted)


static func _sum(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


static func _skips_text(skips: Dictionary) -> String:
	var parts: Array[String] = []
	for slot in ["brush", "shower", "breakfast"]:
		parts.append("%s %d" % [slot, skips.get(slot, 0)])
	return ", ".join(parts)
