class_name LaneSim
extends RefCounted

## Subway-surfers commute with no fail state: 5 lanes, traffic you can NEVER
## crash into. A car ahead inside pin_gap clamps your speed to its speed; a
## car alongside in the target lane blocks the switch. Traffic arrives as waves
## with per-wave and per-car speed variance — a wave usually leaves one lane
## open, but a bad roll walls off all five, and walls shear apart as they roll.
## Reading the shear is the skill; time to cover the route is the only cost.

const LANES := 5
const CARS_PER_WAVE := LANES - 1
const START_LANE := LANES / 2

## Where the dog nominally MEETS the first and last wave, as a fraction of the
## route — nominal because a dog that gets pinned meets everything later.
const FIRST_WAVE_MEET := 0.20
const LAST_WAVE_MEET := 0.85

## Position jitter inside a wave, as a fraction of the route: ±6.0 units on the
## shipped 850-unit route (±5.9 on drive home's 840), well under the 30-unit pin
## gap, so a wave still reads as a wall rather than a smear.
##
## Retuned 0.015 -> 0.007 when the route went 400 -> 900. This is a fraction of
## the route, but the thing it has to stay under — pin_gap — is ABSOLUTE, so
## lengthening the route silently doubled the smear toward the gap it is meant
## to stay clear of. A route change has to re-check it against
## test_a_wave_reads_as_a_wall_not_a_smear.
const WAVE_JITTER := 0.007

var distance: float = 0.0
var lane: int = START_LANE
var speed: float = 0.0
var pinned: bool = false

var _length: float
var _top_speed: float
var _accel: float
var _pin_gap: float
var _block_margin: float
var _switch_lag: float
var _car_min_gap: float
var _lag_left: float = 0.0
var _pending_dir: int = 0
var _cars: Array[Dictionary] = []


func _init(params: Dictionary) -> void:
	_length = params.length
	_top_speed = params.top_speed
	_accel = params.accel
	_pin_gap = params.pin_gap
	_block_margin = params.block_margin
	_switch_lag = params.switch_lag
	_car_min_gap = params.car_min_gap
	for car in params.get("cars", []):
		_cars.append({"lane": car.lane, "pos": car.pos, "speed": car.speed})


## Traffic as a series of walls down the route, with three layers of speed
## randomness stacked on it: one roll for the whole commute (the "you were just
## late today"), one per wave (so a morning is not a flat grind), and one per
## car — the last is what makes a fully blocked wall SHEAR APART as it rolls,
## instead of pinning the dog for the rest of the route.
##
## car_count is still the input contract and is rounded down to whole waves of
## CARS_PER_WAVE, but a blocked wave emits LANES cars rather than CARS_PER_WAVE,
## so the returned array can be LARGER than car_count. Callers size themselves
## off the returned array, never off the product.
static func make_traffic(params: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cars: Array[Dictionary] = []
	var length: float = params.length
	var top: float = params.top_speed
	var waves: int = int(params.car_count) / CARS_PER_WAVE
	var jitter := length * WAVE_JITTER
	var band_low: float = top * params.day_speed_min
	var band_high: float = top * params.day_speed_max
	var wave_jitter: float = params.wave_speed_jitter
	var car_jitter: float = params.car_speed_jitter
	var blocked_chance: float = params.blocked_wave_chance
	# One roll for the whole commute. The player never sees it coming.
	var day_speed := rng.randf_range(band_low, band_high)
	var open_lane := START_LANE
	for w in waves:
		var t := 0.0 if waves < 2 else float(w) / float(waves - 1)
		var wave_speed := clampf(
				day_speed * (1.0 + rng.randf_range(-wave_jitter, wave_jitter)),
				band_low, band_high)
		# Spawned back from where the dog meets it, by however far THIS wave
		# travels on the way there — per wave, now that every wave differs.
		var spawn := length * lerpf(FIRST_WAVE_MEET, LAST_WAVE_MEET, t) \
				* (1.0 - wave_speed / top)
		var blocked := rng.randf() < blocked_chance
		if not blocked:
			open_lane = (open_lane + 1 + rng.randi_range(0, LANES - 2)) % LANES
		for wave_lane in LANES:
			if not blocked and wave_lane == open_lane:
				continue
			cars.append({
				"lane": wave_lane,
				"pos": spawn + rng.randf_range(-jitter, jitter),
				# Clamped at BOTH ends, and both ends are load-bearing. Never
				# zero, or a wall becomes a parked barricade. Never at or past
				# top_speed, or the car stops being an obstacle at all — it just
				# drives away and can never pin the dog. The ceiling is NOT
				# implied by the band: a 0.75 day roll times a 1.35 per-car draw
				# solves to 1.0125 of top speed, which is how a car outran the
				# dog the moment the band was raised for feel.
				"speed": clampf(wave_speed * (1.0 + rng.randf_range(-car_jitter, car_jitter)),
						top * 0.05, top * 0.95),
				# Generation metadata only — _init never copies it into the sim.
				"wave": w,
			})
	# Per-wave speeds break the old guarantee that spawn position rose with the
	# wave index: a later wave that rolls faster is back-computed to a SMALLER
	# spawn and can land on top of an earlier wave in the same lane. The
	# following clamp in _advance_cars cannot rescue that — a car already inside
	# the gap freezes rather than separating — so the overlap would last the
	# whole route. Separate at generation instead, pushing the rear car back so
	# the front car stays exactly where its own back-computation put it.
	var min_gap: float = params.car_min_gap
	for lane in LANES:
		var in_lane: Array[Dictionary] = []
		for car in cars:
			if car.lane == lane:
				in_lane.append(car)
		in_lane.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos > b.pos)
		for i in range(1, in_lane.size()):
			in_lane[i].pos = minf(in_lane[i].pos, in_lane[i - 1].pos - min_gap)
	return cars


func cars() -> Array[Dictionary]:
	return _cars


func route_length() -> float:
	return _length


func top_speed() -> float:
	return _top_speed


## How close a car alongside in the target lane may be before it blocks a switch.
func block_margin() -> float:
	return _block_margin


func request_switch(dir: int) -> void:
	if _lag_left > 0.0:
		return
	_pending_dir = clampi(dir, -1, 1)
	_lag_left = _switch_lag


func tick(delta: float) -> void:
	if is_done():
		return
	if _pending_dir != 0:
		_lag_left -= delta
		if _lag_left <= 0.0:
			_try_switch(_pending_dir)
			_pending_dir = 0
			_lag_left = 0.0
	var limit := _top_speed
	var ahead := _car_ahead()
	if not ahead.is_empty() and ahead.pos - distance <= _pin_gap:
		limit = minf(limit, ahead.speed)
	speed = minf(speed + _accel * delta, limit)
	var unclamped := distance + speed * delta
	var moved := unclamped
	if not ahead.is_empty():
		moved = maxf(distance, minf(moved, ahead.pos - _car_min_gap))
	pinned = limit < _top_speed or moved < unclamped
	if delta > 0.0:
		speed = (moved - distance) / delta
	distance = moved
	_advance_cars(delta)


func is_done() -> bool:
	return distance >= _length


## Traffic obeys the same rule the dog does: a car closes on the one ahead in
## its lane and settles a gap behind it, never through it. Both clamps matter —
## the speed clamp alone still lets a long frame carry a car straight through.
func _advance_cars(delta: float) -> void:
	var front_first := _cars.duplicate()
	front_first.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos > b.pos)
	for car in front_first:
		var lead := _lead_car(car)
		var moving: float = car.speed
		if not lead.is_empty() and lead.pos - car.pos <= _car_min_gap:
			moving = minf(moving, lead.speed)
		var moved: float = car.pos + moving * delta
		if not lead.is_empty():
			moved = maxf(car.pos, minf(moved, lead.pos - _car_min_gap))
		car.pos = moved


## Nearest car strictly ahead in the same lane — a car is never its own lead.
func _lead_car(car: Dictionary) -> Dictionary:
	var best := {}
	for other in _cars:
		if other.lane != car.lane or other.pos <= car.pos:
			continue
		if best.is_empty() or other.pos < best.pos:
			best = other
	return best


func _car_ahead() -> Dictionary:
	var best := {}
	for car in _cars:
		if car.lane == lane and car.pos >= distance:
			if best.is_empty() or car.pos < best.pos:
				best = car
	return best


func _try_switch(dir: int) -> void:
	var target := lane + dir
	if target < 0 or target >= LANES:
		return
	for car in _cars:
		if car.lane == target and absf(car.pos - distance) <= _block_margin:
			return
	lane = target
