class_name DaySchedule
extends RefCounted

const SLOTS := ["wake", "brush", "work_am", "lunch", "work_pm", "dinner", "freetime", "sleep"]

var _index: int = 0


func current() -> String:
	return SLOTS[_index]


func advance() -> bool:
	if _index >= SLOTS.size() - 1:
		return false
	_index += 1
	return true


func reset() -> void:
	_index = 0
