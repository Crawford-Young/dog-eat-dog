extends GutTest


func _params(cars: Array = []) -> Dictionary:
	return {
		"length": 100.0, "top_speed": 10.0, "accel": 1000.0,
		"pin_gap": 10.0, "block_margin": 5.0, "switch_lag": 0.0,
		"cars": cars,
	}


func _run(sim: LaneSim, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(1.0 / 60.0)
		t += 1.0 / 60.0


func test_open_road_reaches_top_speed_and_finishes() -> void:
	var sim := LaneSim.new(_params())
	_run(sim, 11.0)
	assert_true(sim.is_done())
	assert_false(sim.pinned)


func test_car_ahead_pins_speed() -> void:
	var sim := LaneSim.new(_params([{"lane": 1, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 2.0)
	assert_true(sim.pinned)
	assert_almost_eq(sim.speed, 4.0, 0.1)


func test_no_pin_from_car_in_other_lane() -> void:
	var sim := LaneSim.new(_params([{"lane": 0, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 1.0)
	assert_false(sim.pinned)


func test_switch_escapes_pin() -> void:
	var sim := LaneSim.new(_params([{"lane": 1, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 1.0)
	assert_true(sim.pinned)
	sim.request_switch(-1)
	sim.tick(1.0 / 60.0)
	assert_eq(sim.lane, 0)
	_run(sim, 1.0)
	assert_false(sim.pinned)


func test_switch_blocked_by_car_alongside() -> void:
	var sim := LaneSim.new(_params([{"lane": 0, "pos": 0.0, "speed": 0.0}]))
	sim.request_switch(-1)
	sim.tick(1.0 / 60.0)
	assert_eq(sim.lane, 1)  # bounced — car sits at our position in lane 0


func test_switch_clamped_at_road_edge() -> void:
	var sim := LaneSim.new(_params())
	sim.request_switch(-1)
	sim.tick(1.0 / 60.0)
	sim.request_switch(-1)
	sim.tick(1.0 / 60.0)
	assert_eq(sim.lane, 0)


func test_switch_lag_delays_the_change() -> void:
	var p := _params()
	p.switch_lag = 100.0  # absurd window (domain rule): lag must NOT elapse
	var sim := LaneSim.new(p)
	sim.request_switch(-1)
	sim.tick(1.0 / 60.0)
	assert_eq(sim.lane, 1)  # still queued


func test_never_a_crash_speed_snaps_to_slower_car() -> void:
	# Start at full speed straight into a slow car's gap: speed clamps, no state
	# other than pinned changes — there is no crash anywhere in the sim.
	var sim := LaneSim.new(_params([{"lane": 1, "pos": 2.0, "speed": 1.0}]))
	_run(sim, 3.0)
	assert_true(sim.pinned)
	assert_almost_eq(sim.speed, 1.0, 0.1)


func test_make_traffic_spreads_cars_ahead() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cars := LaneSim.make_traffic(8, 400.0, 50.0, rng)
	assert_eq(cars.size(), 8)
	for car in cars:
		assert_between(car.lane, 0, 2)
		assert_gt(car.pos, 0.0)
		assert_lt(car.speed, 50.0)
		assert_gt(car.speed, 0.0)
