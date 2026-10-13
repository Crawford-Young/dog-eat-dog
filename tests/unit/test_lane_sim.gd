extends GutTest

const _STEP := 1.0 / 60.0

## The shipped commute numbers, READ from BalanceConfig rather than copied into
## constants, so the skill properties below are asserted against what the player
## actually drives. Copied constants drift when a tuning pass moves the route, and
## the property tests then measure a geometry that does not ship.
var _route_length: float = BalanceConfig.new().drive_length
var _route_top_speed: float = BalanceConfig.new().drive_top_speed


func _params(cars: Array = []) -> Dictionary:
	return {
		"length": 100.0, "top_speed": 10.0, "accel": 1000.0,
		"pin_gap": 10.0, "block_margin": 5.0, "switch_lag": 0.0,
		"car_min_gap": 10.0, "cars": cars,
	}


func _route_params(cars: Array = []) -> Dictionary:
	return {
		"length": _route_length, "top_speed": _route_top_speed, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_min_gap": 20.0, "cars": cars,
	}


func _run(sim: LaneSim, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(_STEP)
		t += _STEP


## Traffic params default to the SHIPPED numbers so every property below is
## asserted against what the player actually drives; overrides isolate one
## randomness layer at a time.
func _traffic_params(car_count: int, overrides: Dictionary = {}) -> Dictionary:
	var cfg := BalanceConfig.new()
	var p := {
		"length": _route_length, "top_speed": _route_top_speed, "car_count": car_count,
		# The generator separates same-lane cars by this at spawn, so it must be
		# the gap _route_params then drives them against.
		"car_min_gap": 20.0,
		"day_speed_min": cfg.drive_day_speed_min,
		"day_speed_max": cfg.drive_day_speed_max,
		"wave_speed_jitter": cfg.drive_wave_speed_jitter,
		"car_speed_jitter": cfg.drive_car_speed_jitter,
		"blocked_wave_chance": cfg.drive_blocked_wave_chance,
	}
	for key in overrides:
		p[key] = overrides[key]
	return p


func _traffic(seed_value: int, car_count: int = 16,
		overrides: Dictionary = {}) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return LaneSim.make_traffic(_traffic_params(car_count, overrides), rng)


## Waves have no fixed size — a blocked wave carries LANES cars — so the
## generator stamps each car with its wave rather than slicing by a constant.
func _wave(cars: Array[Dictionary], index: int) -> Array[Dictionary]:
	var wave: Array[Dictionary] = []
	for car in cars:
		if car.wave == index:
			wave.append(car)
	return wave


func _wave_count(cars: Array[Dictionary]) -> int:
	var highest := -1
	for car in cars:
		highest = maxi(highest, int(car.wave))
	return highest + 1


## Reads the shear: takes the neighbouring lane whose nearest car ahead is
## furthest away, breaking ties toward the faster car. This is the skill a
## fully blocked wall demands — there is no gap to thread, only a stagger.
func _shear_reader(sim: LaneSim) -> int:
	var best := sim.lane
	var best_score := -INF
	for lane in [sim.lane - 1, sim.lane, sim.lane + 1]:
		if lane < 0 or lane >= LaneSim.LANES:
			continue
		var nearest := INF
		var nearest_speed := 0.0
		for car in sim.cars():
			var gap: float = car.pos - sim.distance
			if car.lane == lane and gap > 0.0 and gap < nearest:
				nearest = gap
				nearest_speed = car.speed
		var score: float = (1000.0 if nearest == INF else nearest) + nearest_speed * 10.0
		if score > best_score:
			best_score = score
			best = lane
	return best


func _drive_shear(sim: LaneSim, cap: float) -> float:
	var t := 0.0
	while t < cap and not sim.is_done():
		var target := _shear_reader(sim)
		if target != sim.lane:
			sim.request_switch(signi(target - sim.lane))
		sim.tick(_STEP)
		t += _STEP
	return t


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


func test_the_road_rules_a_driver_steers_by_are_readable() -> void:
	# The autoplay bot steers off the top speed and the switch-block margin; it
	# reads them through these, never through the sim's private fields.
	var sim := LaneSim.new(_route_params())
	assert_eq(sim.top_speed(), _route_top_speed)
	assert_eq(sim.block_margin(), 25.0)
	assert_eq(sim.route_length(), _route_length)


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
	# pos=15.0, not the route's own car_min_gap(10)-violating 2.0 — issue #14's
	# position clamp makes a car starting closer than car_min_gap to the dog's
	# own position an unrealizable setup (the clamp target is negative from
	# the first tick), which real traffic never produces (make_traffic's own
	# generation-time separation pass guarantees at least car_min_gap).
	var sim := LaneSim.new(_params([{"lane": 2, "pos": 15.0, "speed": 1.0}]))
	_run(sim, 3.0)
	assert_true(sim.pinned)
	assert_almost_eq(sim.speed, 1.0, 0.1)


func test_make_traffic_builds_whole_waves_of_cars_ahead() -> void:
	var cars := _traffic(3)
	assert_eq(_wave_count(cars), 4, "16 cars is still 4 waves — car_count is the input contract")
	assert_gte(cars.size(), 16, "a blocked wave adds a car, never removes one")
	assert_eq(_wave_count(_traffic(3, 4)), 1, "a wave is the smallest unit")
	for car in cars:
		assert_between(car.lane, 0, LaneSim.LANES - 1)
		assert_gt(car.pos, 0.0)
		assert_lt(car.speed, _route_top_speed, "traffic never outruns the dog")
		assert_gt(car.speed, 0.0)


func test_an_unblocked_wave_leaves_one_lane_open_and_a_blocked_one_leaves_none() -> void:
	for seed_value in range(1, 40):
		for car_count in [16, 20]:
			var open_cars := _traffic(seed_value, car_count, {"blocked_wave_chance": 0.0})
			for w in _wave_count(open_cars):
				var wave := _wave(open_cars, w)
				assert_eq(wave.size(), LaneSim.CARS_PER_WAVE,
						"seed %d wave %d is not a one-gap wall" % [seed_value, w])
				assert_between(_open_lane(wave), 0, LaneSim.LANES - 1)
			var walled := _traffic(seed_value, car_count, {"blocked_wave_chance": 1.0})
			for w in _wave_count(walled):
				var wave := _wave(walled, w)
				assert_eq(wave.size(), LaneSim.LANES,
						"seed %d wave %d left a gap it was not supposed to" % [seed_value, w])
				assert_eq(_open_lane(wave), -1,
						"seed %d wave %d is not a full wall" % [seed_value, w])


func test_consecutive_open_walls_never_open_the_same_lane_twice() -> void:
	# The gap is not guaranteed to exist, but where it exists it
	# moves — a straight line through two READABLE walls stays impossible.
	for seed_value in range(1, 40):
		var cars := _traffic(seed_value, 16, {"blocked_wave_chance": 0.0})
		var previous := 2  # the lane the dog starts in
		for w in _wave_count(cars):
			var open_lane := _open_lane(_wave(cars, w))
			assert_ne(open_lane, previous,
					"seed %d wave %d opens where the dog already is" % [seed_value, w])
			previous = open_lane


func test_a_fully_blocked_wall_shears_apart_instead_of_pinning_the_whole_route() -> void:
	# The roll the player can do nothing about: five lanes, no gap. Per-car
	# speed spread is the ONLY escape — the wall staggers down the route and the
	# dog rides the fastest car instead of the slowest. Without that spread this
	# is a soft lock on fun, so this test is what makes the blocked roll legal.
	var cars: Array = []
	for lane in LaneSim.LANES:
		cars.append({"lane": lane, "pos": 60.0, "speed": 10.0 + lane * 1.5})
	var p := _route_params(cars)
	p.length = 1000.0
	var t := _drive_shear(LaneSim.new(p), 90.0)
	var slowest_car_time := 1000.0 / 10.0  # riding the wall's slowest car the whole way
	assert_lt(t, slowest_car_time * 0.85,
			"the dog never got past the slowest car in the wall: %.1fs" % t)


func test_a_commute_of_nothing_but_blocked_walls_still_finishes() -> void:
	# Same property against GENERATED traffic at the worst roll the game can
	# produce: every wave walled, at the densest shipped wave count.
	var densest := BalanceConfig.new().drive_waves_max * LaneSim.CARS_PER_WAVE
	for seed_value in range(1, 9):
		var cars := _traffic(seed_value, densest, {"blocked_wave_chance": 1.0})
		var sim := LaneSim.new(_route_params(cars))
		_drive_shear(sim, 118.0)
		assert_true(sim.is_done(), "seed %d walled the dog in for the whole route" % seed_value)


func test_the_day_roll_keeps_every_car_slower_than_the_dog() -> void:
	var cfg := BalanceConfig.new()
	var floor_speed := _route_top_speed * cfg.drive_day_speed_min \
			* (1.0 - cfg.drive_wave_speed_jitter) * (1.0 - cfg.drive_car_speed_jitter)
	for seed_value in range(1, 40):
		for car in _traffic(seed_value):
			assert_lt(car.speed, _route_top_speed, "seed %d outruns the dog" % seed_value)
			assert_gt(car.speed, floor_speed * 0.5, "seed %d rolled a parked car" % seed_value)


func test_every_wave_rides_the_days_roll_inside_the_configured_band() -> void:
	var cfg := BalanceConfig.new()
	for seed_value in range(1, 40):
		# car jitter off: each wave's cars then share exactly the wave's speed.
		var cars := _traffic(seed_value, 16, {"car_speed_jitter": 0.0})
		for car in cars:
			assert_between(car.speed,
					_route_top_speed * cfg.drive_day_speed_min,
					_route_top_speed * cfg.drive_day_speed_max,
					"seed %d put a wave outside the day band" % seed_value)


func test_two_mornings_do_not_draw_the_same_traffic() -> void:
	# "you were just late today" needs the roll to actually vary.
	assert_ne(_traffic(1)[0].speed, _traffic(2)[0].speed)


func test_each_wall_that_stands_alone_is_back_computed_from_its_own_speed() -> void:
	# Spawn is solved per wave from that wave's own speed, since every wave
	# differs. The claim holds per wave only while the wave
	# is still a wave: a fast roll can back-compute a later wall onto an earlier
	# one, and the generator's separation pass then spreads the merged pair to
	# keep cars from overlapping. A merged pair is one obstacle, not two walls
	# arriving on schedule — the spec accepts that merge as on-intent — so the
	# precision claim is asserted on the walls that still stand alone.
	#
	# The band is PINNED here rather than read from the shipped config, because
	# this test verifies the SOLVE, not the feel. Merging scales with the roll —
	# spacing is length * 0.65 * (1 - roll) / (waves - 1) while a wave's speed spread
	# displaces its spawn by a fixed amount — so any retune toward faster traffic
	# merges more walls and starves the stand-alone population. Reading the
	# shipped band would let a feel retune break a mechanism test (a faster band
	# can drop the stand-alone share below the 60% floor). The pinned band is
	# deliberately LOW and WIDE: low so walls stay clear of each other, wide so
	# the per-wave clamp still admits genuinely different speeds and the per-wave
	# solve stays distinguishable from a shared-speed one.
	var cfg := BalanceConfig.new()
	var gap: float = cfg.drive_car_min_gap
	var checked := 0
	var total := 0
	for seed_value in range(1, 20):
		var cars := _traffic(seed_value, 16, {
			"car_speed_jitter": 0.0,
			"day_speed_min": 0.15,
			"day_speed_max": 0.40,
		})
		var count := _wave_count(cars)
		var lows: Array[float] = []
		var highs: Array[float] = []
		for w in count:
			var low := INF
			var high := -INF
			for car in _wave(cars, w):
				low = minf(low, car.pos)
				high = maxf(high, car.pos)
			lows.append(low)
			highs.append(high)
		var previous := 0.0
		for w in count:
			total += 1
			# Padded by the gap the separation pass enforces, so this is a
			# superset of "the pass moved a car in this wave" — it can skip an
			# untouched wave, never admit a touched one.
			var merged := false
			if w > 0 and lows[w] - gap <= highs[w - 1]:
				merged = true
			if w < count - 1 and lows[w + 1] - gap <= highs[w]:
				merged = true
			if merged:
				continue
			var wave := _wave(cars, w)
			var mean_pos := 0.0
			for car in wave:
				mean_pos += car.pos
			mean_pos /= wave.size()
			var speed: float = wave[0].speed
			# dog at top_speed and the wall at `speed` are level at this point.
			var meet := mean_pos * _route_top_speed / (_route_top_speed - speed)
			var t := 0.0 if count < 2 else float(w) / float(count - 1)
			var intended := _route_length * lerpf(LaneSim.FIRST_WAVE_MEET, LaneSim.LAST_WAVE_MEET, t)
			assert_almost_eq(meet, intended, _route_length * 0.05,
					"seed %d wave %d meets at %.0f, laid out for %.0f" % [seed_value, w, meet, intended])
			assert_gt(meet, previous, "seed %d wave %d is not further down the route" % [seed_value, w])
			previous = meet
			checked += 1
	# A skip rule that quietly swallows everything is not a test. Merges are the
	# rare case; if this ever trips, the layout changed, not the tolerance.
	assert_gt(float(checked) / float(total), 0.6,
			"only %d of %d waves stood alone — the skip rule is eating the test" % [checked, total])


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
	var last := _wave(cars, _wave_count(cars) - 1)
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
	# Skill only pays where there is room to use it. Wall spacing scales with
	# (1 - the day roll), so a fast roll packs the walls tighter than clearing
	# one costs — that morning is lost to luck by design, and asserting skill
	# beats luck there would assert against the whole point of the round.
	var cfg := BalanceConfig.new()
	var light := {
		"blocked_wave_chance": 0.0,
		"day_speed_min": cfg.drive_day_speed_min, "day_speed_max": cfg.drive_day_speed_min,
	}
	# Every wall count a morning ships, not just the fresh dog's: the deficit
	# lerps base -> max, so the counts in between are most mornings.
	for waves in range(cfg.drive_waves_base, cfg.drive_waves_max + 1):
		for seed_value in range(1, 9):
			var traffic := _traffic(seed_value, waves * LaneSim.CARS_PER_WAVE, light)
			var straight := _drive_route(LaneSim.new(_route_params(traffic)), false)
			var weaving := _drive_route(LaneSim.new(_route_params(traffic)), true)
			assert_lt(weaving.time, straight.time,
					"seed %d pays nothing for skill at %d waves" % [seed_value, waves])


func test_a_light_traffic_morning_can_still_be_driven_clean() -> void:
	# Skill has to keep paying on the best roll the game deals. Light traffic is
	# what leaves room: wall spacing is length * 0.65 * (1 - speed_fraction) /
	# (waves - 1), so a SLOW day spreads the walls and a fast one packs them
	# under the ~55 units (pin_gap + block_margin) clearing a wall costs.
	var cfg := BalanceConfig.new()
	var light := {
		"blocked_wave_chance": 0.0, "car_speed_jitter": 0.0,
		"day_speed_min": cfg.drive_day_speed_min, "day_speed_max": cfg.drive_day_speed_min,
	}
	var open_road := _drive_route(LaneSim.new(_route_params()), false)
	for waves in range(cfg.drive_waves_base, cfg.drive_waves_max + 1):
		for seed_value in range(1, 9):
			var cars := _traffic(seed_value, waves * LaneSim.CARS_PER_WAVE, light)
			var run := _drive_route(LaneSim.new(_route_params(cars)), true)
			assert_almost_eq(run.time, open_road.time, 0.5,
					"seed %d cannot be driven clean on the lightest roll at %d waves"
					% [seed_value, waves])


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


## issue #14: the dog pinned to a car's STORED nominal speed, but a jammed car
## is position-clamped behind its lead while its stored speed stays high — the
## dog closed the real gap every frame, crossed the jammed car's position, and
## _car_ahead() handed it the next car. Threaded the whole jam.
func _find_car_by_speed(sim: LaneSim, target_speed: float) -> Dictionary:
	for car in sim.cars():
		if is_equal_approx(car.speed, target_speed):
			return car
	return {}


func _jam_sim() -> LaneSim:
	# Slow lead the rear car cannot get past; the rear's stored speed (60) is
	# far above the route's top speed, but _advance_cars position-clamps it
	# behind the lead almost immediately — jammed, with a high nominal speed.
	var lead := {"lane": 2, "pos": 200.0, "speed": 2.0}
	var rear := {"lane": 2, "pos": 170.0, "speed": 60.0}
	var sim := LaneSim.new(_route_params([lead, rear]))
	sim.lane = 2
	return sim


func test_the_dog_never_drives_through_a_car_jammed_behind_a_slow_lead() -> void:
	var sim := _jam_sim()
	var car_min_gap := 20.0
	var t := 0.0
	while t < 60.0 and not sim.is_done():
		sim.tick(_STEP)
		t += _STEP
		var rear_now := _find_car_by_speed(sim, 60.0)
		assert_false(rear_now.is_empty(), "the rear car never disappears from the sim")
		assert_lte(
			sim.distance, rear_now.pos - car_min_gap,
			"the dog must never cross the jammed car ahead of it",
		)


func test_speedo_reads_the_jams_effective_speed_not_the_jammed_cars_nominal() -> void:
	var sim := _jam_sim()
	_run(sim, 30.0)
	assert_lte(
		sim.speed, 2.0 + 0.5,
		"the speedo must read the jam's real (lead) speed, not the rear car's stored 60",
	)


func test_pinned_is_true_while_position_blocked_behind_the_jam() -> void:
	var sim := _jam_sim()
	_run(sim, 30.0)
	assert_true(sim.pinned, "a dog stuck behind a jam reads pinned")
