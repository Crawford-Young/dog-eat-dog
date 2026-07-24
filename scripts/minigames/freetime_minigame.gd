extends Minigame

## Virtual-cursor fight: OS cursor captured, sprite cursor moved by mouse
## deltas plus a pull toward the game button. Land + click on a button to choose.

var _pull_strength: float = 0.0
var _cursor_pos: Vector2
var _running: bool = false

@onready var _cursor: ColorRect = %VirtualCursor
@onready var _game_btn: Button = %GameButton
@onready var _logoff_btn: Button = %LogoffButton


func setup(params: Dictionary) -> void:
	_pull_strength = params.pull_strength
	_running = true


func _ready() -> void:
	_cursor_pos = size / 2.0


func _process(delta: float) -> void:
	if not _running:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var attractor := _game_btn.get_global_rect().get_center()
	_cursor_pos += TemptationField.pull_offset(_cursor_pos, attractor, _pull_strength, delta)
	_cursor_pos = _cursor_pos.clamp(Vector2.ZERO, size)
	_cursor.position = _cursor_pos - _cursor.size / 2.0


func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseMotion:
		_cursor_pos += event.relative
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_under_cursor()


func _choose_under_cursor() -> void:
	if _logoff_btn.get_global_rect().has_point(_cursor_pos):
		_end("logoff", 1.0)
	elif _game_btn.get_global_rect().has_point(_cursor_pos):
		_end("game", 0.3)


func _end(choice: String, score: float) -> void:
	_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_finish_with({"score": score, "skipped": false, "choice": choice})
