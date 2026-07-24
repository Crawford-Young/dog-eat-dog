extends Minigame

## Nod = 2+ vertical strokes, shake = 2+ horizontal strokes, judged per short
## gesture window. Bubble renders text at tier >= 3, emoji placeholder below.

const BEATS := [
	{"t": 1.5, "cue": "nod", "emoji": "(^o^) !!", "text": "the deadline moved up... wild right?"},
	{"t": 4.0, "cue": "none", "emoji": "(-_-) ~~~", "text": "honestly i just need to vent for a second"},
	{"t": 6.5, "cue": "shake", "emoji": "(o_O) ?!", "text": "and THEN he replied-all again. can you believe it?"},
	{"t": 9.0, "cue": "nod", "emoji": "(^-^) ...", "text": "anyway. lunch again tomorrow?"},
]
const STROKES_FOR_GESTURE := 2
const GESTURE_AMPLITUDE := 30.0

var _session: ListeningSession
var _tier: int = 4
var _nod_tracker: GestureTracker
var _shake_tracker: GestureTracker
var _running: bool = false

@onready var _bubble: Label = %Bubble


func setup(params: Dictionary) -> void:
	_session = ListeningSession.new(BEATS, params.window)
	_tier = params.tier
	_nod_tracker = GestureTracker.new(GestureTracker.AXIS_Y, GESTURE_AMPLITUDE)
	_shake_tracker = GestureTracker.new(GestureTracker.AXIS_X, GESTURE_AMPLITUDE)
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	_session.advance(delta)
	_update_bubble()
	_poll_gesture()
	if _session.is_over():
		_running = false
		_finish(_session.score())


func _update_bubble() -> void:
	var beat := _current_beat()
	if beat.is_empty():
		_bubble.text = ""
	else:
		_bubble.text = beat.text if _tier >= 3 else beat.emoji


func _poll_gesture() -> void:
	if _nod_tracker.stroke_count >= STROKES_FOR_GESTURE:
		_session.gesture("nod")
		_reset_trackers()
	elif _shake_tracker.stroke_count >= STROKES_FOR_GESTURE:
		_session.gesture("shake")
		_reset_trackers()


func _reset_trackers() -> void:
	_nod_tracker.reset()
	_shake_tracker.reset()


func _current_beat() -> Dictionary:
	for beat in BEATS:
		if _session._time >= beat.t and _session._time <= beat.t + _session._window:
			return beat
	return {}


func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		_nod_tracker.feed(event.relative)
		_shake_tracker.feed(event.relative)
