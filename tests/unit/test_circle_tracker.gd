extends GutTest


func _feed_circle(t: CircleTracker, center: Vector2, radius: float, steps: int, turns: float) -> void:
	for i in steps + 1:
		var a := TAU * turns * i / steps
		t.feed(center + Vector2(cos(a), sin(a)) * radius)


func test_full_circle_counts_one_revolution() -> void:
	var t := CircleTracker.new(Vector2(100, 100), 10.0)
	_feed_circle(t, Vector2(100, 100), 40.0, 32, 1.0)
	assert_almost_eq(t.revolutions, 1.0, 0.05)


func test_counterclockwise_counts_too() -> void:
	var t := CircleTracker.new(Vector2.ZERO, 10.0)
	_feed_circle(t, Vector2.ZERO, 40.0, 32, -1.0)
	assert_almost_eq(t.revolutions, 1.0, 0.05)


func test_half_circle_is_half() -> void:
	var t := CircleTracker.new(Vector2.ZERO, 10.0)
	_feed_circle(t, Vector2.ZERO, 40.0, 16, 0.5)
	assert_almost_eq(t.revolutions, 0.5, 0.05)


func test_inside_min_radius_ignored() -> void:
	var t := CircleTracker.new(Vector2.ZERO, 10.0)
	_feed_circle(t, Vector2.ZERO, 5.0, 32, 3.0)
	assert_almost_eq(t.revolutions, 0.0, 0.001)


func test_reentry_after_center_pass_does_not_jump() -> void:
	var t := CircleTracker.new(Vector2.ZERO, 10.0)
	t.feed(Vector2(40, 0))
	t.feed(Vector2(2, 0))    # dive inside dead zone
	t.feed(Vector2(-40, 0))  # re-emerge opposite side
	# no phantom half-revolution from the discontinuity
	assert_almost_eq(t.revolutions, 0.0, 0.001)


func test_retarget_resets() -> void:
	var t := CircleTracker.new(Vector2.ZERO, 10.0)
	_feed_circle(t, Vector2.ZERO, 40.0, 32, 1.0)
	t.retarget(Vector2(200, 200))
	assert_almost_eq(t.revolutions, 0.0, 0.001)
