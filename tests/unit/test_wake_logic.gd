extends GutTest


func _params(target: int = 10, decay: float = 2.0) -> Dictionary:
	return {"mash_target": target, "decay_per_sec": decay}


func test_presses_fill_progress() -> void:
	var w := WakeLogic.new(_params(10, 0.0))
	for i in 5:
		w.press()
	assert_almost_eq(w.progress, 0.5, 0.001)


func test_completes_at_target() -> void:
	var w := WakeLogic.new(_params(10, 0.0))
	for i in 10:
		w.press()
	assert_true(w.is_done())


func test_decay_drains_progress() -> void:
	var w := WakeLogic.new(_params(10, 2.0))  # decay 2 presses/sec
	for i in 5:
		w.press()
	w.tick(1.0)
	assert_almost_eq(w.progress, 0.3, 0.001)  # 0.5 - 2/10


func test_decay_never_below_zero() -> void:
	var w := WakeLogic.new(_params(10, 5.0))
	w.tick(10.0)
	assert_eq(w.progress, 0.0)


func test_done_state_does_not_decay() -> void:
	# BOUNDARY: once out of bed, decay must not pull you back in (games plan-time rule).
	var w := WakeLogic.new(_params(10, 5.0))
	for i in 10:
		w.press()
	w.tick(10.0)
	assert_true(w.is_done())
