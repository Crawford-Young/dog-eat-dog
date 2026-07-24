class_name ListeningSession
extends RefCounted

## Timed cue/response core of Active Listening. Pure logic, engine-free.

var hits: int = 0
var misses: int = 0

var _beats: Array
var _window: float
var _time: float = 0.0
var _answered: Dictionary = {}  # beat index -> true


func _init(beats: Array, window: float) -> void:
	_beats = beats
	_window = window


func advance(dt: float) -> Array:
	var previous := _time
	_time += dt
	var expired: Array = []
	for i in _beats.size():
		var beat: Dictionary = _beats[i]
		var end: float = beat.t + _window
		if end > previous and end <= _time:
			expired.append(beat)
			if beat.cue != "none" and not _answered.has(i):
				misses += 1
				_answered[i] = true
	return expired


func gesture(kind: String) -> String:
	var i := _active_index()
	if i < 0 or _answered.has(i):
		return "idle"
	_answered[i] = true
	var cue: String = _beats[i].cue
	if cue == "none" or cue != kind:
		misses += 1
		return "wrong"
	hits += 1
	return "hit"


func is_over() -> bool:
	return _beats.is_empty() or _time > _beats[-1].t + _window


func score() -> float:
	var cue_count := 0
	for beat in _beats:
		if beat.cue != "none":
			cue_count += 1
	if cue_count == 0:
		return 1.0
	return float(hits) / cue_count


func _active_index() -> int:
	for i in _beats.size():
		var beat: Dictionary = _beats[i]
		if _time >= beat.t and _time <= beat.t + _window:
			return i
	return -1
