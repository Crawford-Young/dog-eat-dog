class_name TypingSession
extends RefCounted

## Punishing typing: a wrong key does not just tick an error counter, it lodges
## in a visible wrong-buffer that blocks ALL further progress until you
## Backspace it out. Backspace is the mechanic, never an error.

const DEFAULT_WRONG_CAP := 5

var typed_count: int = 0
var errors: int = 0
var wrong_buffer: String = ""

var _target: String
var _wrong_cap: int


func _init(target: String, wrong_cap: int = DEFAULT_WRONG_CAP) -> void:
	_target = target
	_wrong_cap = maxi(wrong_cap, 1)


func input_char(c: String) -> bool:
	if is_complete():
		return false
	if wrong_buffer.is_empty() and c == _target[typed_count]:
		typed_count += 1
		return true
	errors += 1
	if wrong_buffer.length() < _wrong_cap:
		wrong_buffer += c
	return false


## Pops one character off the wrong-buffer. Returns false when there was
## nothing to undo — correct progress is never erased.
func backspace() -> bool:
	if wrong_buffer.is_empty():
		return false
	wrong_buffer = wrong_buffer.substr(0, wrong_buffer.length() - 1)
	return true


func is_complete() -> bool:
	return typed_count >= _target.length()


func score(error_tolerance: float) -> float:
	var total := typed_count + errors
	if total == 0:
		return 0.0
	var error_rate := float(errors) / total
	if error_rate <= error_tolerance:
		return 1.0
	return clampf(1.0 - (error_rate - error_tolerance) * 2.0, 0.0, 1.0)
