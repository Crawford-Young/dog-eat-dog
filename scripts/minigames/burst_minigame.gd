extends Minigame

## Work AM's word burst (issue #18): BurstSession streams single words, each
## to be typed before its own bar runs out; the shift timer ends the burst.
## Score = words typed / words shown; a burst under fail_score is a REJECTED
## MISS that keeps its real score, because the work EMA reads it (#17).

const FAIL_GAG := "🚫"
## work_am/monitor.png draws the desk monitor; until it exists, this emoji.
const MONITOR_PLACEHOLDER := "🖥️"
const MONITOR_FONT_SIZE := 260
## How long the next letter shows red after a wrong key.
const WRONG_FLASH_SECONDS := 0.2

var _session: BurstSession
## A burst scoring under this is a MISS; 0 (no param) never misses.
var _fail_score: float = 0.0
var _flash_left: float = 0.0
## What the word label last drew: [word, typed_count, flashing].
var _drawn: Array = []

@onready var _monitor_slot: Control = %MonitorSlot
@onready var _word: RichTextLabel = %WordText
@onready var _word_bar: ProgressBar = %WordBar
@onready var _shift_bar: ProgressBar = %ShiftBar
@onready var _tally: Label = %TallyLabel


func _art_folder() -> String:
	return "work_am"


## The live burst, read-only by contract: the autoplay bot reads the word on
## screen from it and types through real key events.
func session() -> BurstSession:
	return _session


func probe_detail() -> Dictionary:
	return _session.probe_detail() if _session else {}


func _ready() -> void:
	_monitor_slot.add_child(_prop("monitor", MONITOR_PLACEHOLDER, MONITOR_FONT_SIZE))


func setup(params: Dictionary) -> void:
	_session = BurstSession.new(
		params.tier, params.window, params.get("speed", 1.0), RngSource.from_params(params)
	)
	_fail_score = params.get("fail_score", 0.0)
	_start_countdown(params.shift_time)
	_start(params)
	_render()


func _process(delta: float) -> void:
	if not _running:
		return
	_session.tick(delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_render()


## The shift timer is the base countdown: the burst ends when it runs out.
func _on_timeout() -> void:
	var score := _session.score()
	if score < _fail_score:
		_fail(FAIL_GAG, {"score": score})
	else:
		_finish(score)


## The bars move every frame; the word is rebuilt only when it changes.
func _render() -> void:
	_word_bar.value = _session.window_fraction()
	_shift_bar.value = time_fraction()
	var flashing := _flash_left > 0.0
	var state := [_session.word, _session.typed_count, flashing]
	if state == _drawn:
		return
	_drawn = state
	var rest := _session.remaining()
	if flashing:
		rest = "[color=red]%s[/color]%s" % [rest[0], rest.substr(1)]
	_word.text = "[center][color=green]%s[/color]%s[/center]" % [
		_session.word.left(_session.typed_count), rest,
	]
	_tally.text = "typed: %d / %d" % [_session.words_typed, _session.words_shown()]


func _unhandled_key_input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.unicode == 0:
		# Bare modifiers (Shift, Ctrl, Alt...) fire keydown with unicode 0.
		return
	if not _session.input_char(char(event.unicode)):
		_flash_left = WRONG_FLASH_SECONDS
	_render()
