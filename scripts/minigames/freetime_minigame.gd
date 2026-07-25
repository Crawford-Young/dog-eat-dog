extends Minigame

## Virtual-cursor fight, now a loop instead of a choice. The OS cursor is
## captured; the sprite cursor is moved by mouse deltas plus a pull toward the
## game button. Resting on that button auto-plays a game — you never clicked,
## that is the point — and each game pulls harder. Only a deliberate left-click
## on the logoff button gets you out.

var _session: FreetimeSession
var _cursor_pos: Vector2
var _running: bool = false
var _placed: bool = false

@onready var _cursor: ColorRect = %VirtualCursor
@onready var _game_btn: Button = %GameButton
@onready var _logoff_btn: Button = %LogoffButton
@onready var _counter: Label = %Counter


func setup(params: Dictionary) -> void:
	_session = FreetimeSession.new(
		params.pull_strength,
		params.dwell_time,
		params.pull_growth,
		params.pull_ceiling,
	)
	_running = true
	_update_counter()


func _exit_tree() -> void:
	# belt and braces: _end() releases the cursor on the normal path, but a
	# minigame torn down any other way must never strand the OS cursor captured
	_release_cursor()


func _process(delta: float) -> void:
	if not _running:
		return
	if not _placed:
		# anchors only resolve on the first laid-out frame, so _ready is too early
		_placed = true
		_recenter_cursor()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var attractor := _game_btn.get_rect().get_center()
	_cursor_pos += TemptationField.pull_offset(
		_cursor_pos, attractor, _session.pull_strength(), delta
	)
	_cursor_pos = _cursor_pos.clamp(Vector2.ZERO, size)
	_cursor.position = _cursor_pos - _cursor.size / 2.0
	_tick_dwell(delta)


func _tick_dwell(delta: float) -> void:
	if not _game_btn.get_rect().has_point(_cursor_pos):
		_session.leave()
	elif _session.hover(delta):
		# the game finished and dumped you back at the desktop
		_recenter_cursor()
		_update_counter()
	_game_btn.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.3), _session.dwell_ratio())


func _recenter_cursor() -> void:
	_cursor_pos = size / 2.0


func _update_counter() -> void:
	var played := _session.games_played
	_counter.text = "" if played == 0 else "games tonight: %d" % played


func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseMotion:
		_cursor_pos += event.relative
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and _logoff_btn.get_rect().has_point(_cursor_pos):
		_end()


func _end() -> void:
	_running = false
	_release_cursor()
	_session.logoff()
	_finish_with(_session.result())


func _release_cursor() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
