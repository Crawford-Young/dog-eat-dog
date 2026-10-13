extends Minigame

## Swipe left-right to brush. Running out of time is a MISS; the SkipButton
## stays a voluntary skip, never a MISS (issue #17).

const FAIL_GAG := "😬🦷"

var _tracker: GestureTracker
var _strokes_required: int = 6

@onready var _bar: ProgressBar = %BrushBar


func setup(params: Dictionary) -> void:
	_tracker = GestureTracker.new(GestureTracker.AXIS_X, params.amplitude)
	_strokes_required = params.strokes_required
	_start(params)


func _process(_delta: float) -> void:
	if not _running:
		return
	_bar.value = float(_tracker.stroke_count) / _strokes_required
	if _tracker.stroke_count >= _strokes_required:
		_finish(1.0)


func _on_timeout() -> void:
	_fail(FAIL_GAG)


func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		_tracker.feed(event.relative)
