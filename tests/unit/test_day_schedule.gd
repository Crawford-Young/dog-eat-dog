extends GutTest


func test_walks_all_slots_in_order() -> void:
	var d := DaySchedule.new()
	var seen: Array = []
	seen.append(d.current())
	while d.advance():
		seen.append(d.current())
	assert_eq(seen, DaySchedule.SLOTS)


func test_build_normal_day_includes_coffee_before_morning_work() -> void:
	var s := GameState.new()
	var slots := DaySchedule.build(s, BalanceConfig.new())
	assert_eq(slots, ["wake", "brush", "coffee", "work_am", "lunch", "work_pm",
			"dinner", "freetime", "sleep"])


func test_build_inserts_retire_offer_after_wake_at_target() -> void:
	var s := GameState.new()
	s.wallet.credit(BalanceConfig.new().retirement_target)
	var slots := DaySchedule.build(s, BalanceConfig.new())
	assert_eq(slots[0], "wake")
	assert_eq(slots[1], "retire_offer")


func test_build_inserts_warning_beat_before_coffee() -> void:
	var s := GameState.new()
	s.warning = true
	var slots := DaySchedule.build(s, BalanceConfig.new())
	assert_eq(slots.find("warning"), slots.find("brush") + 1)
	assert_lt(slots.find("warning"), slots.find("coffee"))


func test_build_sick_morning_is_just_the_burrow() -> void:
	var s := GameState.new()
	var cfg := BalanceConfig.new()
	s.energy = cfg.sick_energy_threshold - 1.0
	assert_eq(DaySchedule.build(s, cfg), ["sick"] as Array[String])


func test_build_sick_morning_at_target_still_offers_retirement() -> void:
	var s := GameState.new()
	var cfg := BalanceConfig.new()
	s.energy = 0.0
	s.wallet.credit(cfg.retirement_target)
	assert_eq(DaySchedule.build(s, cfg), ["retire_offer", "sick"] as Array[String])


func test_set_slots_resets_the_walk() -> void:
	var d := DaySchedule.new()
	d.advance()
	d.set_slots(["sick"] as Array[String])
	assert_eq(d.current(), "sick")
	assert_false(d.advance())
