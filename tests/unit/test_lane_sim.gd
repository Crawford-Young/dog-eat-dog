extends GutTest

const _STEP := 1.0 / 60.0

## The shipped commute numbers (BalanceConfig drive_*), so the skill properties
## below are asserted against what the player actually drives.
const _ROUTE_LENGTH := 400.0
const _ROUTE_TOP_SPEED := 50.0


func _params(cars: Array = []) -> Dictionary:
	return {
		"length": 100.0, "top_speed": 10.0, "accel": 1000.0,
		"pin_gap": 10.0, "block_margin": 5.0, "switch_lag": 0.0,
		"car_min_gap": 10.0, "cars": cars,
	}


func _route_params(cars: Array = []) -> Dictionary:
	return {
		"length": _ROUTE_LENGTH, "top_speed": _ROUTE_TOP_SPEED, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_min_gap": 20.0, "cars": cars,
	}


func _run(sim: LaneSim, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(_STEP)
		t += _STEP


func _traffic(seed_value: int, car_count: int = 16) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return LaneSim.make_traffic(car_count, _ROUTE_LENGTH, _ROUTE_TOP_SPEED, rng)


func _wave(cars: Array[Dictionary], index: int) -> Array[Dictionary]:
	return cars.slice(index * LaneSim.CARS_PER_WAVE, (index + 1) * LaneSim.CARS_PER_WAVE)


func _open_lane(wave: Array[Dictionary]) -> int:
	var taken := {}
	for car in wave:
		taken[car.lane] = true
	for lane in LaneSim.LANES:
		if not taken.has(lane):
			return lane
	return -1


## A driver that reads the nearest wall ahead and heads for its open lane — the
## behaviour the commute is supposed to demand.
func _open_lane_ahead(sim: LaneSim) -> int:
	var nearest := INF
	for car in sim.cars():
		var gap: float = car.pos - sim.distance
		if gap > 0.0:
			nearest = minf(nearest, gap)
	if nearest > 120.0:
		return sim.lane
	var blocked := {}
	for car in sim.cars():
		var gap: float = car.pos - sim.distance
		# Only the wall being driven into — a wave further down the road is a
		# separate problem with its own gap.
		if gap > 0.0 and gap < nearest + 30.0:
			blocked[car.lane] = true
	if not blocked.has(sim.lane):
		return sim.lane
	for step in LaneSim.LANES:
		for dir in [-1, 1]:
			var lane: int = sim.lane + dir * step
			if lane >= 0 and lane < LaneSim.LANES and not blocked.has(lane):
				return lane
	return sim.lane


func _drive_route(sim: LaneSim, weave: bool) -> Dictionary:
	var t := 0.0
	var pinned := false
	while t < 120.0 and not sim.is_done():
		if weave:
			var target := _open_lane_ahead(sim)
			if target != sim.lane:
				sim.request_switch(signi(target - sim.lane))
		sim.tick(_STEP)
		t += _STEP
		pinned = pinned or sim.pinned
	return {"time": t, "pinned": pinned}


func test_open_road_reaches_top_speed_and_finishes() -> void:
	var sim := LaneSim.new(_params())
	_run(sim, 11.0)
	assert_true(sim.is_done())
	assert_false(sim.pinned)


func test_the_road_has_five_lanes_and_the_dog_starts_in_the_middle() -> void:
	assert_eq(LaneSim.LANES, 5)
	assert_eq(LaneSim.new(_params()).lane, 2)


func test_car_ahead_pins_speed() -> void:
	var sim := LaneSim.new(_params([{"lane": 2, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 2.0)
	assert_true(sim.pinned)
	assert_almost_eq(sim.speed, 4.0, 0.1)


func test_no_pin_from_car_in_other_lane() -> void:
	var sim := LaneSim.new(_params([{"lane": 0, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 1.0)
	assert_false(sim.pinned)


func test_switch_escapes_pin() -> void:
	var sim := LaneSim.new(_params([{"lane": 2, "pos": 5.0, "speed": 4.0}]))
	_run(sim, 1.0)
	assert_true(sim.pinned)
	sim.request_switch(-1)
	sim.tick(_STEP)
	assert_eq(sim.lane, 1)
	_run(sim, 1.0)
	assert_false(sim.pinned)


func test_switch_blocked_by_car_alongside() -> void:
	var sim := LaneSim.new(_params([{"lane": 1, "pos": 0.0, "speed": 0.0}]))
	sim.request_switch(-1)
	sim.tick(_STEP)
	assert_eq(sim.lane, 2)  # bounced — car sits at our position in lane 1


func test_switch_clamped_at_road_edge() -> void:
	var sim := LaneSim.new(_params())
	for i in LaneSim.LANES:  # more presses than there are lanes to the left
		sim.request_switch(-1)
		sim.tick(_STEP)
	assert_eq(sim.lane, 0)


func test_switch_lag_delays_the_change() -> void:
	var p := _params()
	p.switch_lag = 100.0  # absurd window (domain rule): lag must NOT elapse
	var sim := LaneSim.new(p)
	sim.request_switch(-1)
	sim.tick(_STEP)
	assert_eq(sim.lane, 2)  # still queued


func test_never_a_crash_speed_snaps_to_slower_car() -> void:
	# Start at full speed straight into a slow car's gap: speed clamps, no state
	# other than pinned changes — there is no crash anywhere in the sim.
	var sim := LaneSim.new(_params([{"lane": 2, "pos": 2.0, "speed": 1.0}]))
	_run(sim, 3.0)
	assert_true(sim.pinned)
	assert_almost_eq(sim.speed, 1.0, 0.1)


func test_make_traffic_builds_whole_waves_of_cars_ahead() -> void:
	var cars := _traffic(3)
	assert_eq(cars.size(), 16, "16 cars is 4 waves of LANES - 1")
	assert_eq(_traffic(3, 4).size(), LaneSim.CARS_PER_WAVE, "a wave is the smallest unit")
	for car in cars:
		assert_between(car.lane, 0, LaneSim.LANES - 1)
		assert_gt(car.pos, 0.0)
		assert_lt(car.speed, _ROUTE_TOP_SPEED)
		assert_gt(car.speed, 0.0)


func test_every_wave_blocks_every_lane_but_one() -> void:
	for seed_value in range(1, 40):
		var cars := _traffic(seed_value)
		for w in cars.size() / LaneSim.CARS_PER_WAVE:
			var wave := _wave(cars, w)
			var lanes := {}
			for car in wave:
				lanes[car.lane] = true
			assert_eq(lanes.size(), LaneSim.CARS_PER_WAVE,
					"seed %d wave %d doubles up a lane" % [seed_value, w])
			assert_between(_open_lane(wave), 0, LaneSim.LANES - 1)


func test_the_open_lane_never_repeats_so_no_straight_line_survives() -> void:
	for seed_value in range(1, 40):
		var cars := _traffic(seed_value)
		var previous := 2  # the lane the dog starts in
		for w in cars.size() / LaneSim.CARS_PER_WAVE:
			var open_lane := _open_lane(_wave(cars, w))
			assert_ne(open_lane, previous,
					"seed %d wave %d opens where the dog already is" % [seed_value, w])
			previous = open_lane


func test_a_wave_reads_as_a_wall_not_a_smear() -> void:
	for seed_value in range(1, 40):
		var cars := _traffic(seed_value)
		for w in cars.size() / LaneSim.CARS_PER_WAVE:
			var lowest := INF
			var highest := -INF
			for car in _wave(cars, w):
				lowest = minf(lowest, car.pos)
				highest = maxf(highest, car.pos)
			assert_lt(highest - lowest, 30.0,
					"seed %d wave %d smears past the pin gap" % [seed_value, w])


func test_waves_are_spread_down_the_route_with_room_to_read_the_first() -> void:
	var cars := _traffic(7)
	var first := _wave(cars, 0)
	for car in first:
		assert_gt(car.pos, 25.0, "the first wall starts beyond the block margin")
	var last := _wave(cars, cars.size() / LaneSim.CARS_PER_WAVE - 1)
	assert_gt(last[0].pos, first[0].pos, "later waves sit further down the route")


func test_holding_one_lane_never_holds_top_speed() -> void:
	# The whole point of the rework: a straight line gets pinned and pays for
	# it, at the lightest traffic the game ships as much as the heaviest.
	var cfg := BalanceConfig.new()
	for seed_value in range(1, 9):
		for waves in [cfg.drive_waves_base, cfg.drive_waves_max]:
			var cars := _traffic(seed_value, waves * LaneSim.CARS_PER_WAVE)
			var run := _drive_route(LaneSim.new(_route_params(cars)), false)
			assert_true(run.pinned,
					"seed %d let a straight line through %d waves" % [seed_value, waves])
			assert_gt(run.time, 10.0,
					"seed %d cost a straight line nothing at %d waves" % [seed_value, waves])


func test_weaving_to_the_open_lane_beats_holding_a_lane() -> void:
	for seed_value in range(1, 9):
		var straight := _drive_route(LaneSim.new(_route_params(_traffic(seed_value))), false)
		var weaving := _drive_route(LaneSim.new(_route_params(_traffic(seed_value))), true)
		assert_lt(weaving.time, straight.time,
				"seed %d pays nothing for skill" % seed_value)


func test_the_fresh_morning_commute_can_be_driven_flat_out() -> void:
	# The shipped base wave count has to leave room to weave: read the walls
	# right and the dog is never pinned, so the route costs open-road time.
	# Raising drive_waves_base past what the block margin and pin gap allow
	# between walls breaks this — deliberately, that is what a deficit does.
	var cfg := BalanceConfig.new()
	var open_road := _drive_route(LaneSim.new(_route_params()), false)
	for seed_value in range(1, 9):
		var cars := _traffic(seed_value, cfg.drive_waves_base * LaneSim.CARS_PER_WAVE)
		var run := _drive_route(LaneSim.new(_route_params(cars)), true)
		assert_almost_eq(run.time, open_road.time, 0.5,
				"seed %d cannot be driven clean at the base wave count" % seed_value)


func test_a_faster_car_settles_behind_a_slower_one_instead_of_passing_through() -> void:
	var p := _params([
		{"lane": 0, "pos": 40.0, "speed": 2.0},
		{"lane": 0, "pos": 10.0, "speed": 8.0},
	])
	p.length = 1000.0
	var sim := LaneSim.new(p)
	_run(sim, 8.0)
	var leader: Dictionary = sim.cars()[0]
	var follower: Dictionary = sim.cars()[1]
	assert_lt(follower.pos, leader.pos, "the fast car drove through the slow one")
	assert_almost_eq(leader.pos - follower.pos, 10.0, 0.2, "it should settle a gap behind")


func test_a_car_cannot_jump_through_another_on_a_long_delta() -> void:
	var p := _params([
		{"lane": 0, "pos": 40.0, "speed": 2.0},
		{"lane": 0, "pos": 10.0, "speed": 8.0},
	])
	p.length = 1000.0
	var sim := LaneSim.new(p)
	sim.tick(5.0)  # one absurd frame: the speed clamp alone would not hold
	var leader: Dictionary = sim.cars()[0]
	var follower: Dictionary = sim.cars()[1]
	assert_lt(follower.pos, leader.pos, "a long frame teleported a car through another")
	assert_gt(leader.pos - follower.pos, 9.9, "and it still keeps its gap")


func test_a_car_already_inside_the_gap_holds_instead_of_being_shoved_back() -> void:
	var p := _params([
		{"lane": 0, "pos": 40.0, "speed": 2.0},
		{"lane": 0, "pos": 35.0, "speed": 8.0},  # already closer than car_min_gap
	])
	p.length = 1000.0
	var sim := LaneSim.new(p)
	_run(sim, 1.0)
	var follower: Dictionary = sim.cars()[1]
	assert_eq(follower.pos, 35.0, "it waited for the gap to open instead of jumping back")
	_run(sim, 7.0)
	assert_almost_eq(sim.cars()[0].pos - follower.pos, 10.0, 0.2, "then it settles a gap behind")


func test_cars_in_different_lanes_pass_each_other_freely() -> void:
	var p := _params([
		{"lane": 0, "pos": 40.0, "speed": 2.0},
		{"lane": 1, "pos": 10.0, "speed": 8.0},
	])
	p.length = 1000.0
	var sim := LaneSim.new(p)
	_run(sim, 8.0)
	assert_gt(sim.cars()[1].pos, sim.cars()[0].pos, "another lane is not blocked")


func _closest_same_lane_pair(cars: Array[Dictionary]) -> float:
	var closest := INF
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			if cars[i].lane == cars[j].lane:
				closest = minf(closest, absf(cars[i].pos - cars[j].pos))
	return closest


func test_generated_traffic_never_overlaps_itself_over_a_whole_route() -> void:
	# Run at the heaviest traffic the game ships — that is where walls sit
	# closest together and a wave could start inside the car gap.
	var densest := BalanceConfig.new().drive_waves_max * LaneSim.CARS_PER_WAVE
	for seed_value in range(1, 9):
		var sim := LaneSim.new(_route_params(_traffic(seed_value, densest)))
		var closest := INF
		var t := 0.0
		while t < 120.0 and not sim.is_done():
			sim.tick(_STEP)
			t += _STEP
			closest = minf(closest, _closest_same_lane_pair(sim.cars()))
		assert_gt(closest, 1.0, "seed %d overlapped two cars in a lane" % seed_value)
