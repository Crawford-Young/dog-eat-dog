class_name LaneSim
extends RefCounted

## Subway-surfers commute with no fail state: 5 lanes, traffic you can NEVER
## crash into. A car ahead inside pin_gap clamps your speed to its speed; a
## car alongside in the target lane blocks the switch. Traffic arrives as waves
## that fill every lane but one, and no wave leaves the same lane open as the
## one before it — so no straight line survives the route. Weaving to hold top
## speed is the whole skill — time to cover the route is the only cost.

const LANES := 5
const CARS_PER_WAVE := LANES - 1
const START_LANE := LANES / 2

## Where the dog nominally MEETS the first and last wave, as a fraction of the
## route — nominal because a dog that gets pinned meets everything later.
const FIRST_WAVE_MEET := 0.20
const LAST_WAVE_MEET := 0.85

## Every wave rolls at the same share of top speed. Uniform is load-bearing: it
## holds the walls exactly as far apart as they were laid out for the whole
## route, so no wave ever rear-ends the one ahead and the room left to weave
## between two walls is the room the wave count gave it.
const WAVE_SPEED := 0.40

## Position jitter inside a wave, as a fraction of the route: ±6 units on the
## shipped 400-unit route, well under the 30-unit pin gap, so a wave still reads
## as a wall rather than a smear.
const WAVE_JITTER := 0.015

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


## Traffic as a series of walls down the route. car_count is rounded down to
## whole waves of CARS_PER_WAVE. Each wave fills every lane but one; the first
## never opens the lane the dog starts in and no wave repeats the one before it,
## so holding a lane always ends up pinned — weaving is mandatory by
## construction, not by tuning a density knob.
static func make_traffic(car_count: int, length: float, top_speed: float,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cars: Array[Dictionary] = []
	var waves := car_count / CARS_PER_WAVE
	var jitter := length * WAVE_JITTER
	var speed := top_speed * WAVE_SPEED
	var open_lane := START_LANE
	for w in waves:
		var t := 0.0 if waves < 2 else float(w) / float(waves - 1)
		# Spawned back from where the dog meets it, by however far the wave
		# itself travels on the way there.
		var spawn := length * lerpf(FIRST_WAVE_MEET, LAST_WAVE_MEET, t) * (1.0 - WAVE_SPEED)
		open_lane = (open_lane + 1 + rng.randi_range(0, LANES - 2)) % LANES
		for wave_lane in LANES:
			if wave_lane == open_lane:
				continue
			cars.append({
				"lane": wave_lane,
				"pos": spawn + rng.randf_range(-jitter, jitter),
				"speed": speed,
			})
	return cars


func cars() -> Array[Dictionary]:
	return _cars


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
	pinned = limit < _top_speed
	speed = minf(speed + _accel * delta, limit)
	distance += speed * delta
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
