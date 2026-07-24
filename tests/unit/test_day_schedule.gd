extends GutTest


func test_walks_all_slots_in_order() -> void:
	var d := DaySchedule.new()
	var seen: Array = []
	seen.append(d.current())
	while d.advance():
		seen.append(d.current())
	assert_eq(seen, DaySchedule.SLOTS)


func test_reset_returns_to_wake() -> void:
	var d := DaySchedule.new()
	d.advance()
	d.reset()
	assert_eq(d.current(), "wake")
