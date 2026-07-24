class_name GestureTracker
extends RefCounted

## Counts directional strokes along one axis from relative mouse deltas.
## A stroke = accumulated same-direction movement >= min_amplitude; the same
## direction cannot count twice without a reversal in between.

const AXIS_X := 0
const AXIS_Y := 1

var stroke_count: int = 0

var _axis: int
var _min_amplitude: float
var _sign: float = 0.0
var _accum: float = 0.0
var _last_counted: float = 0.0


func _init(axis: int, min_amplitude: float) -> void:
	_axis = axis
	_min_amplitude = min_amplitude


func feed(delta: Vector2) -> void:
	var v := delta.x if _axis == AXIS_X else delta.y
	if is_zero_approx(v):
		return
	var s := signf(v)
	if s != _sign:
		_sign = s
		_accum = 0.0
	_accum += absf(v)
	if _accum >= _min_amplitude and s != _last_counted:
		stroke_count += 1
		_last_counted = s
		_accum = 0.0


func reset() -> void:
	stroke_count = 0
	_sign = 0.0
	_accum = 0.0
	_last_counted = 0.0
