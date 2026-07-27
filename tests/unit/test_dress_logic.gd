extends GutTest


func test_starts_naked() -> void:
	assert_eq(DressLogic.new().worn.size(), 0)


func test_wear_free_item() -> void:
	var d := DressLogic.new()
	assert_true(d.wear("shirt"))
	assert_true("shirt" in d.worn)


func test_shoes_require_pants() -> void:
	var d := DressLogic.new()
	assert_false(d.can_wear("shoes"))
	assert_false(d.wear("shoes"))
	assert_true(d.wear("pants"))
	assert_true(d.wear("shoes"))


func test_cannot_wear_twice() -> void:
	var d := DressLogic.new()
	assert_true(d.wear("shirt"))
	assert_false(d.wear("shirt"))


func test_unknown_item_refused() -> void:
	assert_false(DressLogic.new().wear("hat"))


func test_dressed_when_all_four_on() -> void:
	var d := DressLogic.new()
	for item in ["shirt", "pants", "shoes", "collar"]:
		assert_true(d.wear(item))
	assert_true(d.is_dressed())


func test_not_dressed_at_three() -> void:
	var d := DressLogic.new()
	for item in ["shirt", "pants", "shoes"]:
		d.wear(item)
	assert_false(d.is_dressed())
