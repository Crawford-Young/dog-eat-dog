class_name WorkShift
extends RefCounted

## One work block under the shift timer: phrases stream until time runs out.
## Throughput (completed phrases + fractional progress) vs par is the score.
## Accuracy still punishes through the wrong-buffer: jammed keys cost time.

var target: String = ""
var session: TypingSession
var units_done: int = 0

var _tier: int
var _wrong_cap: int
var _rng: RandomNumberGenerator


func _init(tier: int, wrong_cap: int, rng: RandomNumberGenerator) -> void:
	_tier = tier
	_wrong_cap = wrong_cap
	_rng = rng
	_next_phrase()


func _next_phrase() -> void:
	target = TextForge.generate(_tier, _rng)
	session = TypingSession.new(target, _wrong_cap)


func input_char(c: String) -> void:
	session.input_char(c)
	if session.is_complete():
		units_done += 1
		_next_phrase()


func backspace() -> void:
	session.backspace()


func progress() -> float:
	return units_done + float(session.typed_count) / maxf(target.length(), 1.0)


func score(par_units: int) -> float:
	if par_units <= 0:
		return 0.0
	return clampf(progress() / par_units, 0.0, 1.0)
