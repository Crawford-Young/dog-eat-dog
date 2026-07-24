extends GutTest


func test_pull_points_toward_attractor() -> void:
	var offset := TemptationField.pull_offset(Vector2(0, 0), Vector2(100, 0), 60.0, 1.0)
	assert_almost_eq(offset.x, 60.0, 0.001)
	assert_almost_eq(offset.y, 0.0, 0.001)


func test_pull_scales_with_dt() -> void:
	var offset := TemptationField.pull_offset(Vector2(0, 0), Vector2(100, 0), 60.0, 0.5)
	assert_almost_eq(offset.x, 30.0, 0.001)


func test_zero_at_contact() -> void:
	var offset := TemptationField.pull_offset(Vector2(100, 0), Vector2(100, 0), 60.0, 1.0)
	assert_eq(offset, Vector2.ZERO)


func test_zero_strength_is_zero_pull() -> void:
	var offset := TemptationField.pull_offset(Vector2(0, 0), Vector2(100, 0), 0.0, 1.0)
	assert_eq(offset, Vector2.ZERO)
