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
	assert_eq(slots, ["wake", "brush", "shower", "clothes", "breakfast", "drive",
			"coffee", "work_am", "lunch", "work_pm", "drive_home", "dinner", "freetime", "sleep"])


func test_default_morning_order_wave3a() -> void:
	var state := GameState.new()
	var cfg := BalanceConfig.new()
	var slots := DaySchedule.build(state, cfg)
	var morning := slots.slice(0, 6)
	assert_eq(morning, ["wake", "brush", "shower", "clothes", "breakfast", "drive"])


func test_build_inserts_retire_offer_after_wake_at_target() -> void:
	var s := GameState.new()
	s.wallet.credit(BalanceConfig.new().retirement_target)
	var slots := DaySchedule.build(s, BalanceConfig.new())
	assert_eq(slots[0], "wake")
	assert_eq(slots[1], "retire_offer")


## The warning talk is an office beat now — it waits for the dog to arrive,
## landing between the commute and the coffee cart.
func test_warning_lands_after_drive_before_coffee() -> void:
	var state := GameState.new()
	state.warning = true
	var cfg := BalanceConfig.new()
	var slots := DaySchedule.build(state, cfg)
	assert_eq(slots[slots.find("drive") + 1], "warning")
	assert_eq(slots[slots.find("warning") + 1], "coffee")


func test_sick_morning_still_collapses() -> void:
	var state := GameState.new()
	var cfg := BalanceConfig.new()
	state.energy = 5.0
	var slots := DaySchedule.build(state, cfg)
	assert_false("shower" in slots)
	assert_false("drive" in slots)


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


func test_the_drive_home_sits_between_afternoon_work_and_dinner() -> void:
	var slots := DaySchedule.build(GameState.new(), BalanceConfig.new())
	var home := slots.find("drive_home")
	assert_gt(home, slots.find("work_pm"), "you leave the office after the office")
	assert_lt(home, slots.find("dinner"), "and you cook after you get there")


func test_the_schedule_reports_its_slots_and_position() -> void:
	var d := DaySchedule.new()
	var day: Array[String] = ["wake", "breakfast", "sleep"]
	d.set_slots(day)
	assert_eq(d.slots(), day)
	assert_eq(d.index(), 0)
	d.advance()
	d.advance()
	assert_eq(d.index(), 2)
	d.set_slots(["sick"] as Array[String])
	assert_eq(d.index(), 0, "a new day starts at its first slot")


func test_the_reported_slots_cannot_rewrite_the_day() -> void:
	var d := DaySchedule.new()
	d.slots().append("extra")
	assert_eq(d.slots(), DaySchedule.DEFAULT_SLOTS)
