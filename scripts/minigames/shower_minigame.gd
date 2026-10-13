extends Minigame

## Scrub the stink spots: circle the mouse around each spot until it's clean,
## then the next one appears. Skippable — the stink follows you (summary line).
## Running out of time is a MISS; a skip never is (issue #17). The stinky dog,
## the showerhead on the cursor and each spot's shrinking stink cloud are
## presentation only: the spot's own square stays the hit area.

const FAIL_GAG := "🤢🚿"
## shower/<name>.png draws each prop; until it exists, these emoji.
const DOG_PLACEHOLDER := "🐕"
const SHOWERHEAD_PLACEHOLDER := "🚿"
const CLOUD_PLACEHOLDER := "💨"
const DOG_FONT_SIZE := 240
const SHOWERHEAD_FONT_SIZE := 72
const CLOUD_FONT_SIZE := 64
## How small a cloud gets just before its spot comes clean, as a scale.
const CLOUD_MIN_SCALE := 0.25

const SPOT_POSITIONS := [
	Vector2(0.35, 0.4), Vector2(0.6, 0.55), Vector2(0.45, 0.7),
	Vector2(0.55, 0.3), Vector2(0.4, 0.55),
]

var _tracker: CircleTracker
var _spots_left: int = 2
var _revolutions_required: float = 2.0
var _min_radius: float = 12.0
var _cloud: Control

@onready var _spot: Control = %Spot
@onready var _bar: ProgressBar = %ScrubBar
@onready var _dog_slot: Control = %DogSlot
@onready var _showerhead_slot: Control = %ShowerheadSlot


func _art_folder() -> String:
	return "shower"


func _ready() -> void:
	_dog_slot.add_child(_prop("dog", DOG_PLACEHOLDER, DOG_FONT_SIZE))
	_showerhead_slot.add_child(
			_prop("showerhead", SHOWERHEAD_PLACEHOLDER, SHOWERHEAD_FONT_SIZE))
	_cloud = _prop("cloud", CLOUD_PLACEHOLDER, CLOUD_FONT_SIZE)
	_spot.add_child(_cloud)
	_follow(get_global_mouse_position())


func setup(params: Dictionary) -> void:
	_spots_left = params.spots
	_revolutions_required = params.revolutions
	_min_radius = params.min_radius
	_place_spot()
	_start(params)


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
	_bar.value = _scrubbed()
	if _tracker.revolutions >= _revolutions_required:
		_spots_left -= 1
		if _spots_left <= 0:
			_finish(1.0)
		else:
			_place_spot()
	_shrink_cloud()


## The current spot's scrub, 0 fresh to 1 clean.
func _scrubbed() -> float:
	return clampf(_tracker.revolutions / _revolutions_required, 0.0, 1.0)


## The cloud shrinks about its centre as its spot is scrubbed; the spot keeps
## its size.
func _shrink_cloud() -> void:
	_cloud.pivot_offset = _cloud.size / 2.0
	_cloud.scale = Vector2.ONE * lerpf(1.0, CLOUD_MIN_SCALE, _scrubbed())


func _on_timeout() -> void:
	_fail(FAIL_GAG)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	_follow(event.position)
	if _running:
		_tracker.feed(event.position)


## Centres the showerhead on the cursor.
func _follow(cursor: Vector2) -> void:
	_showerhead_slot.global_position = cursor - _showerhead_slot.size / 2.0
