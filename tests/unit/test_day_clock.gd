extends GutTest


func test_starts_full() -> void:
	var c := DayClock.new(120.0)
	assert_almost_eq(c.remaining(), 120.0, 0.001)
	assert_almost_eq(c.overrun(), 0.0, 0.001)


func test_spend_reduces_remaining() -> void:
	var c := DayClock.new(120.0)
	c.spend(45.0)
	assert_almost_eq(c.remaining(), 75.0, 0.001)


func test_spend_ignores_negative() -> void:
	var c := DayClock.new(120.0)
	c.spend(-10.0)
	assert_almost_eq(c.remaining(), 120.0, 0.001)


func test_overrun_accumulates_past_budget() -> void:
	var c := DayClock.new(60.0)
	c.spend(75.0)
	assert_almost_eq(c.remaining(), 0.0, 0.001)
	assert_almost_eq(c.overrun(), 15.0, 0.001)


func test_zone_calm_amber_red() -> void:
	var c := DayClock.new(100.0)
	assert_eq(c.zone(0.4, 0.15), "calm")
	c.spend(65.0)  # 35% left
	assert_eq(c.zone(0.4, 0.15), "amber")
	c.spend(25.0)  # 10% left
	assert_eq(c.zone(0.4, 0.15), "red")


func test_zone_red_when_overrun() -> void:
	var c := DayClock.new(60.0)
	c.spend(90.0)
	assert_eq(c.zone(0.4, 0.15), "red")


func test_zone_boundary_is_inclusive() -> void:
	var c := DayClock.new(100.0)
	c.spend(60.0)  # exactly 40% left -> amber starts
	assert_eq(c.zone(0.4, 0.15), "amber")


func test_clock_text_formats_start() -> void:
	var c := DayClock.new(120.0)
	assert_eq(c.clock_text(420), "7:00")


func test_clock_text_advances_with_spend() -> void:
	var c := DayClock.new(120.0)
	c.spend(42.0)
	assert_eq(c.clock_text(420), "7:42")


func test_clock_text_pads_minutes_and_rolls_hour() -> void:
	var c := DayClock.new(120.0)
	c.spend(65.0)
	assert_eq(c.clock_text(420), "8:05")


func test_zero_budget_is_red_immediately() -> void:
	var c := DayClock.new(0.0)
	assert_eq(c.zone(0.4, 0.15), "red")


func test_format_minutes_renders_a_wall_clock_time() -> void:
	assert_eq(DayClock.format_minutes(510), "8:30")
	assert_eq(DayClock.format_minutes(420), "7:00")
	assert_eq(DayClock.format_minutes(485), "8:05")


func test_clock_text_still_renders_through_the_shared_formatter() -> void:
	var c := DayClock.new(90.0)
	c.spend(42.0)
	assert_eq(c.clock_text(420), DayClock.format_minutes(462))
