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


func test_a_clock_with_no_bands_names_no_band() -> void:
	var clock := DayClock.new(60.0)
	assert_eq(clock.band_name(), "", "the morning has one deadline and no band to name")


func test_bands_name_the_window_the_clock_is_in() -> void:
	var clock := DayClock.new(210.0)
	clock.set_bands(
		PackedStringArray(["early", "mid", "late"]), PackedFloat32Array([120.0, 210.0])
	)
	assert_eq(clock.band_name(), "early")
	clock.spend(119.0)
	assert_eq(clock.band_name(), "early", "one minute short of the line is still early")
	clock.spend(1.0)
	assert_eq(clock.band_name(), "mid", "crossing a line lands in the next band")
	clock.spend(90.0)
	assert_eq(clock.band_name(), "late")
	clock.spend(500.0)
	assert_eq(clock.band_name(), "late", "there is no band past the last one")


func test_next_line_retargets_and_runs_out() -> void:
	var clock := DayClock.new(210.0)
	clock.set_bands(
		PackedStringArray(["early", "mid", "late"]), PackedFloat32Array([120.0, 210.0])
	)
	assert_eq(clock.next_line(), 120.0)
	clock.spend(120.0)
	assert_eq(clock.next_line(), 210.0, "the readout retargets to the line still makeable")
	clock.spend(90.0)
	assert_eq(clock.next_line(), -1.0, "the final band has nothing left to be late for")


func test_zone_measures_the_current_band_not_the_whole_run() -> void:
	var clock := DayClock.new(210.0)
	clock.set_bands(
		PackedStringArray(["early", "mid", "late"]), PackedFloat32Array([120.0, 210.0])
	)
	# 60 of the first band's 120 minutes gone: half of THIS band remains, which
	# is calm, even though only 150 of the whole 210 remain.
	clock.spend(60.0)
	assert_eq(clock.zone(0.4, 0.15), "calm")
	# 108 gone: 12 of this band's 120 left = 0.1, under the red fraction. Red
	# arrives before the early night is lost — the wave-3a telegraph property.
	clock.spend(48.0)
	assert_eq(clock.zone(0.4, 0.15), "red", "red telegraphs losing a band, not just being late")
	# Into the second band, which is measured on its own 90-minute span.
	clock.spend(20.0)
	assert_eq(clock.zone(0.4, 0.15), "calm", "a fresh band starts calm again")


func test_the_last_band_is_permanently_red() -> void:
	var clock := DayClock.new(210.0)
	clock.set_bands(
		PackedStringArray(["early", "mid", "late"]), PackedFloat32Array([120.0, 210.0])
	)
	clock.spend(210.0)
	assert_eq(clock.zone(0.4, 0.15), "red")
	clock.spend(600.0)
	assert_eq(clock.zone(0.4, 0.15), "red", "still red ten hours later — there is no worse band")


func test_the_morning_is_the_one_segment_case_of_the_same_math() -> void:
	# The generalization must not move the morning by a hair. Same budget, one
	# clock with an explicit single line and one with none: identical zones all
	# the way through and past the deadline.
	var bare := DayClock.new(60.0)
	var lined := DayClock.new(60.0)
	lined.set_bands(PackedStringArray(["on time", "late"]), PackedFloat32Array([60.0]))
	for _i in range(14):
		bare.spend(5.0)
		lined.spend(5.0)
		assert_eq(
			bare.zone(0.4, 0.15), lined.zone(0.4, 0.15), "zones diverged at %f" % bare.elapsed
		)
