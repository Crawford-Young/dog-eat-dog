class_name LaneSim
extends RefCounted

## Subway-surfers commute with no fail state: 3 lanes, traffic you can NEVER
## crash into. A car ahead inside pin_gap clamps your speed to its speed; a
## car alongside in the target lane blocks the switch. Weaving to hold top
## speed is the whole skill — time to cover the route is the only cost.

const LANES := 3

var distance: float = 0.0
var lane: int = 1
var speed: float = 0.0
var pinned: bool = false

var _length: float
var _top_speed: float
var _accel: float
var _pin_gap: float
var _block_margin: float
var _switch_lag: float
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
	for car in params.get("cars", []):
		_cars.append({"lane": car.lane, "pos": car.pos, "speed": car.speed})


static func make_traffic(count: int, length: float, top_speed: float,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cars: Array[Dictionary] = []
	for i in count:
		cars.append({
			"lane": rng.randi_range(0, LANES - 1),
			"pos": length * (0.15 + 0.8 * (float(i) + rng.randf()) / count),
			"speed": top_speed * rng.randf_range(0.3, 0.7),
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
	for car in _cars:
		car.pos += car.speed * delta


func is_done() -> bool:
	return distance >= _length


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
