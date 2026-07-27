extends Minigame

## The commute. Hold top speed by weaving; you can never crash — traffic just
## slows you down, and slow is what costs (the day clock keeps running).

var _sim: LaneSim
var _running: bool = false
var _route_length: float = 1.0
var _car_rects: Array[ColorRect] = []

@onready var _road: ColorRect = %Road
@onready var _player: ColorRect = %Player
@onready var _progress: ProgressBar = %DriveBar
@onready var _honk: Label = %Honk

const PIXELS_PER_UNIT := 4.0


func setup(params: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sim_params := params.duplicate()
	sim_params["cars"] = LaneSim.make_traffic(
			params.car_count, params.length, params.top_speed, rng)
	_sim = LaneSim.new(sim_params)
	_route_length = params.length
	for car in _sim.cars():
		var rect := ColorRect.new()
		rect.size = Vector2(48, 72)
		rect.color = Color(0.7, 0.55, 0.75, 1)
		_road.add_child(rect)
		_car_rects.append(rect)
	_running = true


func _lane_x(lane_index: int) -> float:
	return _road.size.x * (0.5 + lane_index) / LaneSim.LANES


func _process(delta: float) -> void:
	if not _running:
		return
	_sim.tick(delta)
	_player.position.x = _lane_x(_sim.lane) - _player.size.x / 2.0
	var sim_cars := _sim.cars()
	for i in _car_rects.size():
		var car: Dictionary = sim_cars[i]
		var rect := _car_rects[i]
		rect.position.x = _lane_x(car.lane) - rect.size.x / 2.0
		rect.position.y = _player.position.y \
				- (car.pos - _sim.distance) * PIXELS_PER_UNIT
		rect.visible = rect.position.y > -80.0 and rect.position.y < _road.size.y + 80.0
	_progress.value = clampf(_sim.distance / _route_length, 0.0, 1.0)
	_honk.visible = _sim.pinned
	if _sim.is_done():
		_running = false
		_finish(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT:
			_sim.request_switch(-1)
		KEY_D, KEY_RIGHT:
			_sim.request_switch(1)
