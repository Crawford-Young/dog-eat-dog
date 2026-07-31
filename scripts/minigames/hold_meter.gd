class_name HoldMeter
extends RefCounted

## A held gesture's fill, and the band that reads as "release now". Ramps up
## only while ticked — the caller decides when that is (holding). No reset:
## a fresh instance is one attempt, same as CircleTracker and BeatTimer.

var value: float = 0.0

var _speed: float
var _band_center: float
var _band_width: float


func _init(speed: float, band_center: float, band_width: float) -> void:
	_speed = speed
	_band_center = band_center
	_band_width = band_width


func tick(delta: float) -> void:
	value = minf(value + _speed * delta, 1.0)


func release() -> bool:
	return absf(value - _band_center) <= _band_width / 2.0
