class_name Typewriter
extends RefCounted

## Elapsed time in, visible character count out. Pure, fully tested — the
## node-side driver that pushes the text at a Label lives in TypewriterLabel.

const DEFAULT_CHARS_PER_SEC := 30.0

var _text: String
var _chars_per_sec: float
var _elapsed: float = 0.0
var _skipped: bool = false


func _init(text: String, chars_per_sec: float = DEFAULT_CHARS_PER_SEC) -> void:
	restart(text, chars_per_sec)


func restart(text: String, chars_per_sec: float = -1.0) -> void:
	_text = text
	if chars_per_sec >= 0.0:
		_chars_per_sec = chars_per_sec
	_elapsed = 0.0
	_skipped = false


func advance(dt: float) -> void:
	_elapsed += dt


func skip() -> void:
	_skipped = true


func visible_count() -> int:
	if _skipped or _chars_per_sec <= 0.0:
		return _text.length()
	return mini(int(_elapsed * _chars_per_sec), _text.length())


func visible_text() -> String:
	return _text.substr(0, visible_count())


func is_done() -> bool:
	return visible_count() >= _text.length()
