extends Minigame

## Swipe left-right to brush. Running out of time is a MISS; the SkipButton
## stays a voluntary skip, never a MISS (issue #17). The brush prop rides the
## cursor over the mouth prop; both are presentation only.

const FAIL_GAG := "😬🦷"
## brush/<name>.png draws each prop; until it exists, these emoji.
const MOUTH_PLACEHOLDER := "👄"
const BRUSH_PLACEHOLDER := "🪥"
const MOUTH_FONT_SIZE := 180
const BRUSH_FONT_SIZE := 72

var _tracker: GestureTracker
var _strokes_required: int = 6

@onready var _bar: ProgressBar = %BrushBar
@onready var _mouth_slot: Control = %MouthSlot
@onready var _brush_slot: Control = %BrushSlot


func _art_folder() -> String:
	return "brush"


func _ready() -> void:
	_mouth_slot.add_child(_prop("mouth", MOUTH_PLACEHOLDER, MOUTH_FONT_SIZE))
	_brush_slot.add_child(_prop("brush", BRUSH_PLACEHOLDER, BRUSH_FONT_SIZE))
	_follow(get_global_mouse_position())


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
	if not event is InputEventMouseMotion:
		return
	_follow(event.position)
	if _running:
		_tracker.feed(event.relative)


## Centres the brush on the cursor.
func _follow(cursor: Vector2) -> void:
	_brush_slot.global_position = cursor - _brush_slot.size / 2.0
