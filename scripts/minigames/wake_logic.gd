class_name WakeLogic
extends RefCounted

var progress: float:
	get:
		return _count / _mash_target

var _mash_target: int
var _decay_per_sec: float
var _count: float = 0.0


func _init(params: Dictionary) -> void:
	_mash_target = params.mash_target
	_decay_per_sec = params.decay_per_sec


func press() -> void:
	_count = minf(_count + 1.0, float(_mash_target))


func tick(dt: float) -> void:
	if is_done():
		return
	_count = maxf(_count - _decay_per_sec * dt, 0.0)


func is_done() -> bool:
	return _count >= float(_mash_target)
