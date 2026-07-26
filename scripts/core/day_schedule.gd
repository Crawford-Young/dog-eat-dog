class_name DaySchedule
extends RefCounted

## Walks one day's slot list. Wave 2: the list is built per morning from
## state (sick short-circuit, retire offer, warning beat, coffee cart).

const DEFAULT_SLOTS: Array[String] = ["wake", "brush", "work_am", "lunch",
		"work_pm", "dinner", "freetime", "sleep"]

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
	slots.append("brush")
	if state.warning:
		slots.append("warning")
	slots.append_array(["coffee", "work_am", "lunch", "work_pm", "dinner",
			"freetime", "sleep"])
	return slots


func set_slots(slots: Array[String]) -> void:
	_slots = slots
	_index = 0


func current() -> String:
	return _slots[_index]


func advance() -> bool:
	if _index >= _slots.size() - 1:
		return false
	_index += 1
	return true


func reset() -> void:
	_index = 0
