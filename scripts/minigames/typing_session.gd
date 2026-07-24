class_name TypingSession
extends RefCounted

var typed_count: int = 0
var errors: int = 0

var _target: String


func _init(target: String) -> void:
	_target = target


func input_char(c: String) -> bool:
	if is_complete():
		return false
	if c == _target[typed_count]:
		typed_count += 1
		return true
	errors += 1
	return false


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
