extends Minigame

## Scrub the stink spots: circle the mouse around each spot until it's clean,
## then the next one appears. Skippable — the stink follows you (summary line).

var _tracker: CircleTracker
var _spots_left: int = 2
var _revolutions_required: float = 2.0
var _min_radius: float = 12.0

@onready var _spot: ColorRect = %Spot
@onready var _bar: ProgressBar = %ScrubBar

const SPOT_POSITIONS := [
	Vector2(0.35, 0.4), Vector2(0.6, 0.55), Vector2(0.45, 0.7),
	Vector2(0.55, 0.3), Vector2(0.4, 0.55),
]


func setup(params: Dictionary) -> void:
	_spots_left = params.spots
	_revolutions_required = params.revolutions
	_min_radius = params.min_radius
	_place_spot()
	_start()


func _place_spot() -> void:
	var frac: Vector2 = SPOT_POSITIONS[_spots_left % SPOT_POSITIONS.size()]
	_spot.position = size * frac - _spot.size / 2.0
	var center := _spot.position + _spot.size / 2.0
	if _tracker == null:
		_tracker = CircleTracker.new(center, _min_radius)
	else:
		_tracker.retarget(center)


func _process(_delta: float) -> void:
	if not _running:
		return
	_bar.value = clampf(_tracker.revolutions / _revolutions_required, 0.0, 1.0)
	if _tracker.revolutions >= _revolutions_required:
		_spots_left -= 1
		if _spots_left <= 0:
			_finish(1.0)
		else:
			_place_spot()


func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		_tracker.feed(event.position)
