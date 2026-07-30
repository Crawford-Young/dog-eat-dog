class_name DayClock
extends RefCounted

## The morning's time budget in game-minutes. game.gd is the only spender —
## it converts real seconds to game-minutes and adds fixed skip costs. No
## minigame touches this directly (wave-3a invariant).

var budget: float
var elapsed: float = 0.0
## Offsets from this clock's start where the bands change, ascending. Empty for
## the morning, which has one deadline and needs none.
var lines: PackedFloat32Array = PackedFloat32Array()
## One entry MORE than `lines` — the band after the last line. Empty when no
## bands are set.
var band_names: PackedStringArray = PackedStringArray()


func _init(budget_minutes: float) -> void:
	budget = maxf(budget_minutes, 0.0)


func spend(minutes: float) -> void:
	elapsed += maxf(minutes, 0.0)


func remaining() -> float:
	return maxf(budget - elapsed, 0.0)


func overrun() -> float:
	return maxf(elapsed - budget, 0.0)


## Bands turn the one-deadline morning clock into the evening's banded one.
## `line_minutes` are offsets from this clock's start, ascending; `names`
## carries one more entry than lines, for the band past the final one.
func set_bands(names: PackedStringArray, line_minutes: PackedFloat32Array) -> void:
	band_names = names
	lines = line_minutes


## Start and end of the band the clock is in right now. The end is INF past the
## final line — the last band has no deadline left to count toward, which is
## exactly what keeps it red. With no bands set this is (0, budget): the morning
## is the single-segment case of the same math, not a special case beside it.
func segment() -> Vector2:
	var prev := 0.0
	for line in (lines if not lines.is_empty() else PackedFloat32Array([budget])):
		if elapsed < line:
			return Vector2(prev, line)
		prev = line
	return Vector2(prev, INF)


## The offset of the line the clock is counting toward, or -1.0 in the final
## band, where there is nothing left to be late for.
func next_line() -> float:
	var seg := segment()
	return -1.0 if is_inf(seg.y) else seg.y


## The band the clock is in — "early" / "mid" / "late" for the evening. Empty
## for the morning, which names no bands.
func band_name() -> String:
	if band_names.is_empty():
		return ""
	var index := 0
	for line in lines:
		if elapsed < line:
			break
		index += 1
	return band_names[mini(index, band_names.size() - 1)]


## "calm" -> "amber" -> "red" as the CURRENT band drains. Red is the telegraph:
## it always arrives before the thing it warns about, whether that thing is the
## morning's lateness debit or the evening losing a bedtime band.
func zone(amber_fraction: float, red_fraction: float) -> String:
	var seg := segment()
	if is_inf(seg.y):
		return "red"
	var span := seg.y - seg.x
	var frac := (seg.y - elapsed) / span if span > 0.0 else 0.0
	if frac <= red_fraction:
		return "red"
	if frac <= amber_fraction:
		return "amber"
	return "calm"


## Wall-clock rendering for any absolute game-minute value — the current time,
## or the deadline the HUD prints beside it.
static func format_minutes(total_minutes: int) -> String:
	var hours := int(total_minutes / 60.0) % 24
	return "%d:%02d" % [hours, total_minutes % 60]


func clock_text(start_minutes: int) -> String:
	return format_minutes(start_minutes + int(elapsed))
