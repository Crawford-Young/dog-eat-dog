class_name CircleTracker
extends RefCounted

## Accumulates mouse revolutions around a center. Direction-agnostic —
## scrubbing clockwise or counter-clockwise both clean. Positions inside
## min_radius are a dead zone: angles there are noise, and crossing the
## center must never register as a half-turn jump.

var revolutions: float = 0.0

var _center: Vector2
var _min_radius: float
var _last_angle: float = 0.0
var _has_last: bool = false


func _init(center: Vector2, min_radius: float) -> void:
	_center = center
	_min_radius = min_radius


func feed(pos: Vector2) -> void:
	var offset := pos - _center
	if offset.length() < _min_radius:
		_has_last = false
		return
	var angle := offset.angle()
	if _has_last:
		revolutions += absf(wrapf(angle - _last_angle, -PI, PI)) / TAU
	_last_angle = angle
	_has_last = true


func retarget(center: Vector2) -> void:
	_center = center
	revolutions = 0.0
	_has_last = false
