extends GutTest


func test_starts_at_zero() -> void:
	assert_almost_eq(BeatTimer.new(1.0, 0.3).position, 0.0, 0.001)


func test_tick_advances() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(0.25)
	assert_almost_eq(b.position, 0.25, 0.001)


func test_reflects_at_one() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(1.2)
	assert_almost_eq(b.position, 0.8, 0.001)


func test_reflects_back_at_zero() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(2.1)  # 0 -> 1 -> 0 -> 0.1
	assert_almost_eq(b.position, 0.1, 0.001)


func test_press_hits_inside_window() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(0.5)
	assert_true(b.press())


func test_press_misses_outside_window() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(0.1)
	assert_false(b.press())


func test_just_inside_window_is_a_hit() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(0.64)  # 0.14 from center, window half-width 0.15
	assert_true(b.press())


func test_just_outside_window_is_a_miss() -> void:
	var b := BeatTimer.new(1.0, 0.3)
	b.tick(0.66)  # 0.16 from center
	assert_false(b.press())
