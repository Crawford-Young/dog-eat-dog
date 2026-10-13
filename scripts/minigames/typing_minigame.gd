extends Minigame

## A fixed-length shift: phrases stream, the timer is the boss. Green = typed,
## red = jammed wrong keys — Backspace is the only way forward. Score is
## throughput vs the rank's par; a shift under fail_score is a MISS that keeps
## its real score, because the work EMA reads it (issue #17).

const FAIL_GAG := "📉"

var _shift: WorkShift
var _par_units: int = 3
## A shift scoring under this is a MISS; 0 (no param) never misses.
var _fail_score: float = 0.0

@onready var _text: RichTextLabel = %WorkText
@onready var _timer_bar: ProgressBar = %ShiftBar
@onready var _units_label: Label = %UnitsLabel


func setup(params: Dictionary) -> void:
	_shift = WorkShift.new(params.tier, params.get("wrong_cap", TypingSession.DEFAULT_WRONG_CAP), RngSource.from_params(params))
	_start_countdown(params.shift_time)
	_par_units = params.par_units
	_fail_score = params.get("fail_score", 0.0)
	_start(params)
	_render()


func _process(_delta: float) -> void:
	if _running:
		_timer_bar.value = time_fraction()


## The shift timer is the base countdown: the shift ends when it runs out.
func _on_timeout() -> void:
	var score := _shift.score(_par_units)
	if score < _fail_score:
		_fail(FAIL_GAG, {"score": score})
	else:
		_finish(score)


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
