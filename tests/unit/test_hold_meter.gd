extends GutTest


func test_value_ramps_with_speed() -> void:
	var meter := HoldMeter.new(0.5, 0.75, 0.2)
	meter.tick(1.0)
	assert_almost_eq(meter.value, 0.5, 0.001)


func test_value_clamps_at_one() -> void:
	var meter := HoldMeter.new(0.5, 0.75, 0.2)
	meter.tick(10.0)
	assert_eq(meter.value, 1.0)


func test_release_is_true_inside_the_band() -> void:
	var meter := HoldMeter.new(1.0, 0.75, 0.2)
	meter.tick(0.75)
	assert_true(meter.release())


func test_release_is_false_below_the_band() -> void:
	var meter := HoldMeter.new(1.0, 0.75, 0.2)
	meter.tick(0.5)
	assert_false(meter.release())


func test_release_is_false_above_the_band() -> void:
	var meter := HoldMeter.new(1.0, 0.75, 0.2)
	meter.tick(1.0)
	assert_false(meter.release())


func test_release_boundary_is_inclusive() -> void:
	# band_center 0.75, width 0.2 -> the edge sits at 0.85, exactly width/2 away.
	var meter := HoldMeter.new(1.0, 0.75, 0.2)
	meter.tick(0.85)
	assert_true(meter.release())


func test_a_zero_width_band_accepts_only_the_exact_center() -> void:
	var on_center := HoldMeter.new(1.0, 0.75, 0.0)
	on_center.tick(0.75)
	assert_true(on_center.release())
	var off_center := HoldMeter.new(1.0, 0.75, 0.0)
	off_center.tick(0.751)
	assert_false(off_center.release())
