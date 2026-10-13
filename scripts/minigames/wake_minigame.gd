extends Minigame

## Mash SPACE to fill the bar. A bar still short of full at the time limit is
## a MISS (issue #17). The alarm clock on the nightstand rattles faster as the
## countdown bar falls; that is presentation only.

const FAIL_GAG := "😴⏰"
## wake/clock.png draws the alarm clock; until it exists, this emoji.
const CLOCK_PLACEHOLDER := "⏰"
const CLOCK_FONT_SIZE := 96
## Shakes per second with a full countdown bar, and with an empty one.
const RATTLE_HZ_CALM := 3.0
const RATTLE_HZ_FRANTIC := 14.0
## How far the clock tips either way while it rattles, in radians.
const RATTLE_ANGLE := 0.25

var _logic: WakeLogic
var _rattle_phase := 0.0

@onready var _bar: ProgressBar = %WakeBar
@onready var _clock_slot: Control = %ClockSlot


## Shakes per second at a countdown `fraction` (1 full, 0 empty): the emptier
## the bar, the faster the rattle.
static func rattle_hz(fraction: float) -> float:
	return lerpf(RATTLE_HZ_FRANTIC, RATTLE_HZ_CALM, clampf(fraction, 0.0, 1.0))


func _art_folder() -> String:
	return "wake"


func _ready() -> void:
	_clock_slot.add_child(_prop("clock", CLOCK_PLACEHOLDER, CLOCK_FONT_SIZE))


func setup(params: Dictionary) -> void:
	_logic = WakeLogic.new(params)
	_start(params)


func _process(delta: float) -> void:
	if not _running:
		return
	_logic.tick(delta)
	_bar.value = _logic.progress
	_rattle(delta)
	if _logic.is_done():
		_finish(1.0)


## Tips the clock to and fro, faster as the countdown runs down. An untimed
## game rattles at the calm rate.
func _rattle(delta: float) -> void:
	var fraction := time_fraction() if has_countdown() else 1.0
	_rattle_phase = fmod(_rattle_phase + delta * TAU * rattle_hz(fraction), TAU)
	_clock_slot.pivot_offset = _clock_slot.size / 2.0
	_clock_slot.rotation = sin(_rattle_phase) * RATTLE_ANGLE


func _on_timeout() -> void:
	if _logic.is_done():
		_finish(1.0)
	else:
		_fail(FAIL_GAG)


func _unhandled_input(event: InputEvent) -> void:
	if _running and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		_logic.press()
