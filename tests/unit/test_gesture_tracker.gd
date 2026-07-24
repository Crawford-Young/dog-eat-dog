extends GutTest


func _feed_n(t: GestureTracker, delta: Vector2, n: int) -> void:
	for i in n:
		t.feed(delta)


func test_one_direction_counts_one_stroke() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_X, 40.0)
	_feed_n(t, Vector2(10, 0), 5)  # 50px right
	assert_eq(t.stroke_count, 1)


func test_continuing_same_direction_does_not_double_count() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_X, 40.0)
	_feed_n(t, Vector2(10, 0), 20)  # 200px right, still one stroke
	assert_eq(t.stroke_count, 1)


func test_reversal_counts_second_stroke() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_X, 40.0)
	_feed_n(t, Vector2(10, 0), 5)
	_feed_n(t, Vector2(-10, 0), 5)
	assert_eq(t.stroke_count, 2)


func test_jitter_below_amplitude_ignored() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_X, 40.0)
	for i in 20:
		t.feed(Vector2(3 if i % 2 == 0 else -3, 0))
	assert_eq(t.stroke_count, 0)


func test_axis_isolation() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_Y, 40.0)
	_feed_n(t, Vector2(100, 0), 5)  # pure horizontal, tracker is vertical
	assert_eq(t.stroke_count, 0)
	_feed_n(t, Vector2(0, 10), 5)
	assert_eq(t.stroke_count, 1)


func test_reset() -> void:
	var t := GestureTracker.new(GestureTracker.AXIS_X, 40.0)
	_feed_n(t, Vector2(10, 0), 5)
	t.reset()
	assert_eq(t.stroke_count, 0)
