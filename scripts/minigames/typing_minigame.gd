extends Minigame

## A fixed-length shift: phrases stream, the timer is the boss. Green = typed,
## red = jammed wrong keys — Backspace is the only way forward. Score is
## throughput vs the rank's par.

var _shift: WorkShift
var _shift_left: float = 25.0
var _par_units: int = 3
var _running: bool = false

@onready var _text: RichTextLabel = %WorkText
@onready var _timer_bar: ProgressBar = %ShiftBar
@onready var _units_label: Label = %UnitsLabel

var _shift_time: float = 25.0


func setup(params: Dictionary) -> void:
	_shift = WorkShift.new(params.tier, params.get("wrong_cap", TypingSession.DEFAULT_WRONG_CAP), RngSource.from_params(params))
	_shift_time = params.shift_time
	_shift_left = params.shift_time
	_par_units = params.par_units
	_running = true
	_render()


func _process(delta: float) -> void:
	if not _running:
		return
	_shift_left -= delta
	_timer_bar.value = _shift_left / _shift_time
	if _shift_left <= 0.0:
		_running = false
		_finish(_shift.score(_par_units))


func _render() -> void:
	var done := _shift.target.substr(0, _shift.session.typed_count)
	var rest := _shift.target.substr(_shift.session.typed_count)
	_text.text = "[color=green]%s[/color][color=red]%s[/color]%s" % [
		done,
		_shift.session.wrong_buffer,
		rest,
	]
	_units_label.text = "done: %d / %d" % [_shift.units_done, _par_units]


func _unhandled_key_input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_BACKSPACE:
		_shift.backspace()
		_render()
		return
	if event.unicode == 0:
		# Bare modifiers (Shift, Ctrl, Alt...) fire keydown with unicode 0.
		# char(0) is a length-1 NUL string — letting it through jams the buffer.
		return
	_shift.input_char(char(event.unicode))
	_render()
