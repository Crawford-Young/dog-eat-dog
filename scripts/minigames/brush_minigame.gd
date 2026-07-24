extends Minigame

var _tracker: GestureTracker
var _strokes_required: int = 6
var _par_time: float = 5.0
var _elapsed: float = 0.0
var _running: bool = false

@onready var _bar: ProgressBar = %BrushBar


func setup(params: Dictionary) -> void:
	_tracker = GestureTracker.new(GestureTracker.AXIS_X, params.amplitude)
	_strokes_required = params.strokes_required
	_par_time = params.par_time
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_bar.value = float(_tracker.stroke_count) / _strokes_required
	if _tracker.stroke_count >= _strokes_required:
		_running = false
		_finish(clampf(_par_time / maxf(_elapsed, 0.01), 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if _running and event is InputEventMouseMotion:
		_tracker.feed(event.relative)


func _on_skip_pressed() -> void:
	if _running:
		_running = false
		_finish(0.0, true)
