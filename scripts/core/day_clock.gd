class_name DayClock
extends RefCounted

## The morning's time budget in game-minutes. game.gd is the only spender —
## it converts real seconds to game-minutes and adds fixed skip costs. No
## minigame touches this directly (wave-3a invariant).

var budget: float
var elapsed: float = 0.0


func _init(budget_minutes: float) -> void:
	budget = maxf(budget_minutes, 0.0)


func spend(minutes: float) -> void:
	elapsed += maxf(minutes, 0.0)


func remaining() -> float:
	return maxf(budget - elapsed, 0.0)


func overrun() -> float:
	return maxf(elapsed - budget, 0.0)


## "calm" -> "amber" -> "red" as the budget drains. Red is the lateness
## telegraph: overrun can only ever begin from a visibly red clock.
func zone(amber_fraction: float, red_fraction: float) -> String:
	var frac := remaining() / budget if budget > 0.0 else 0.0
	if frac <= red_fraction:
		return "red"
	if frac <= amber_fraction:
		return "amber"
	return "calm"


func clock_text(start_minutes: int) -> String:
	var total := start_minutes + int(elapsed)
	var hours := int(total / 60.0) % 24
	return "%d:%02d" % [hours, total % 60]
