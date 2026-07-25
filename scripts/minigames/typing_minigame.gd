extends Minigame

## Green = typed, red = the wrong keys jammed in the buffer. Nothing advances
## while red is on screen — Backspace is the only way forward.

var _session: TypingSession
var _tolerance: float = 0.3
var _target: String = ""
var _running: bool = false

@onready var _text: RichTextLabel = %WorkText


func setup(params: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_target = TextForge.generate(params.tier, rng)
	_session = TypingSession.new(_target, params.get("wrong_cap", TypingSession.DEFAULT_WRONG_CAP))
	_tolerance = params.error_tolerance
	_running = true
	_render()


func _render() -> void:
	var done := _target.substr(0, _session.typed_count)
	var rest := _target.substr(_session.typed_count)
	_text.text = "[color=green]%s[/color][color=red]%s[/color]%s" % [
		done,
		_session.wrong_buffer,
		rest,
	]


func _unhandled_key_input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_BACKSPACE:
		_session.backspace()
		_render()
		return
	var c := char(event.unicode)
	if c == "":
		return
	_session.input_char(c)
	_render()
	if _session.is_complete():
		_running = false
		_finish(_session.score(_tolerance))
