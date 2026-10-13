extends Minigame

## Nod = 2+ vertical strokes, shake = 2+ horizontal strokes, judged per short
## gesture window. Bubble renders text at tier >= 3, emoji placeholder below.
## A lunch scoring under fail_score is a MISS that keeps its real score
## (issue #17).

const BEATS := [
	{"t": 1.5, "cue": "nod", "emoji": "😃 ❗❗", "text": "the deadline moved up... wild right?"},
	{"t": 4.0, "cue": "none", "emoji": "😩 💨", "text": "honestly i just need to vent for a second"},
	{"t": 6.5, "cue": "shake", "emoji": "🤯 ?!", "text": "and THEN he replied-all again. can you believe it?"},
	{"t": 9.0, "cue": "nod", "emoji": "😊 ...", "text": "anyway. lunch again tomorrow?"},
]
const STROKES_FOR_GESTURE := 2
const GESTURE_AMPLITUDE := 30.0
const FAIL_GAG := "🙉"

var _session: ListeningSession
var _tier: int = 4
## A lunch scoring under this is a MISS; 0 (no param) never misses.
var _fail_score: float = 0.0
var _text_speed: float = Typewriter.DEFAULT_CHARS_PER_SEC
var _spoken: String = ""
var _nod_tracker: GestureTracker
var _shake_tracker: GestureTracker

@onready var _bubble: Label = %Bubble
@onready var _typer := TypewriterLabel.new()


func _art_folder() -> String:
	return "lunch"


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_bubble)
	PropArt.with_emoji_fallback(_bubble)


func setup(params: Dictionary) -> void:
	_session = ListeningSession.new(BEATS, params.window)
	_tier = params.tier
	_text_speed = params.get("text_speed", _text_speed)
	_fail_score = params.get("fail_score", 0.0)
	_nod_tracker = GestureTracker.new(GestureTracker.AXIS_Y, GESTURE_AMPLITUDE)
	_shake_tracker = GestureTracker.new(GestureTracker.AXIS_X, GESTURE_AMPLITUDE)
	_start(params)


func _process(delta: float) -> void:
	if not _running:
		return
	_session.advance(delta)
	_update_bubble()
	_poll_gesture()
	if _session.is_over():
		var score := _session.score()
		if score < _fail_score:
			_fail(FAIL_GAG, {"score": score})
		else:
			_finish(score)


func _update_bubble() -> void:
	var beat := _session.active_beat()
	var line: String = "" if beat.is_empty() else (beat.text if _tier >= 3 else beat.emoji)
	if line != _spoken:
		_spoken = line
		_typer.play(line, _text_speed)


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


func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		_nod_tracker.feed(event.relative)
		_shake_tracker.feed(event.relative)
