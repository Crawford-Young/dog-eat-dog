class_name BeatTimer
extends RefCounted

## One timing beat: a cursor ping-pongs 0..1, press() hits when it's inside
## the centered window. Window width comes from energy via Difficulty.

var position: float = 0.0

var _speed: float
var _window: float
var _dir: float = 1.0


func _init(speed: float, window: float) -> void:
	_speed = speed
	_window = clampf(window, 0.0, 1.0)


func tick(delta: float) -> void:
	position += _dir * _speed * delta
	while position > 1.0 or position < 0.0:
		if position > 1.0:
			position = 2.0 - position
			_dir = -1.0
		else:
			position = -position
			_dir = 1.0


func press() -> bool:
	return absf(position - 0.5) <= _window / 2.0
