class_name DaySchedule
extends RefCounted

## Walks one day's slot list. Wave 2: the list is built per morning from
## state (sick short-circuit, retire offer, warning beat, coffee cart).
## Wave 3a: the morning is a triage run — shower, clothes, breakfast and the
## commute all share one draining clock, and the warning talk waits until the
## dog has actually arrived.

const DEFAULT_SLOTS: Array[String] = ["wake", "brush", "shower", "clothes",
		"breakfast", "drive", "work_am", "lunch", "work_pm", "drive_home",
		"dinner", "freetime", "sleep"]

## Wave-1 name kept as an alias — test_day_flow.gd's scene smoke walk still
## reads DaySchedule.SLOTS to drive main.tscn through a default day.
const SLOTS := DEFAULT_SLOTS

var _slots: Array[String] = DEFAULT_SLOTS
var _index: int = 0


static func build(state: GameState, cfg: BalanceConfig) -> Array[String]:
	var slots: Array[String] = []
	var retiring_available := state.wallet.can_retire(cfg.retirement_target)
	if Difficulty.is_sick_morning(state.energy, cfg):
		if retiring_available:
			slots.append("retire_offer")
		slots.append("sick")
		return slots
	slots.append("wake")
	if retiring_available:
		slots.append("retire_offer")
	slots.append_array(["brush", "shower", "clothes", "breakfast", "drive"])
	# The warning talk is an office beat — it lands after the commute, never in
	# the bathroom.
	if state.warning:
		slots.append("warning")
	slots.append_array(["coffee", "work_am", "lunch", "work_pm", "drive_home",
			"dinner", "freetime", "sleep"])
	return slots


func set_slots(slots: Array[String]) -> void:
	_slots = slots
	_index = 0


func current() -> String:
	return _slots[_index]


## A copy of the day, so a reader can never reshape it.
func slots() -> Array[String]:
	return _slots.duplicate()


## Where the walk is in slots(): the current slot's position.
func index() -> int:
	return _index


func advance() -> bool:
	if _index >= _slots.size() - 1:
		return false
	_index += 1
	return true
