class_name TypewriterLabel
extends Node

## Node-side driver for Typewriter: add one as a child, bind it to a Label or
## RichTextLabel once, then play() a line per beat. The pure pacing logic lives
## in Typewriter — this is only the pump that pushes text at the control.

signal completed

var _writer: Typewriter
var _target: Control
var _emitted: bool = true


func bind(target: Control) -> void:
	_target = target


func play(text: String, chars_per_sec: float = Typewriter.DEFAULT_CHARS_PER_SEC) -> void:
	_writer = Typewriter.new(text, chars_per_sec)
	_emitted = false
	_render()


## Unwired by design — whether a keypress should skip a line is a playtest
## ruling, not an implementer call, so the affordance ships ready and inert.
func skip() -> void:
	if _writer == null:
		return
	_writer.skip()
	_render()


func is_done() -> bool:
	return _writer == null or _writer.is_done()


func _process(delta: float) -> void:
	if _writer == null:
		return
	if not _writer.is_done():
		_writer.advance(delta)
		_render()
	if _writer.is_done() and not _emitted:
		_emitted = true
		completed.emit()


func _render() -> void:
	if _target != null:
		_target.set("text", _writer.visible_text())
