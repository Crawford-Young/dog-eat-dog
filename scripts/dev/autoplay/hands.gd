extends RefCounted

## The bot's hands: the only place an InputEvent is built. Every event goes in
## through Input.parse_input_event, so it reaches _input, the GUI and
## _unhandled_input exactly as a player's would.
##
## Positions are given in viewport (game) coordinates and mapped to window
## coordinates through the root's final transform before sending. Headless
## shrinks the root window to 64x64 and canvas_items stretch scales the
## 1280x720 game into it, so a raw viewport point sent as-is lands far off
## screen; the engine applies the inverse transform on the way in.

## How long a tapped key stays down, in frames.
const TAP_FRAMES := 2

var mouse := Vector2(640.0, 360.0)
var mouse_down := false

var _root: Window
## [frames_left, keycode] pairs waiting for their release event.
var _pending_releases: Array = []


func _init(root: Window) -> void:
	_root = root


## Called once per frame by the runner, before the drivers act.
func tick() -> void:
	var still: Array = []
	for entry in _pending_releases:
		entry[0] -= 1
		if entry[0] <= 0:
			key(entry[1], false)
		else:
			still.append(entry)
	_pending_releases = still


func key(keycode: Key, pressed: bool, unicode: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.unicode = unicode
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Press now, release TAP_FRAMES later.
func tap(keycode: Key, unicode: int = 0) -> void:
	key(keycode, true, unicode)
	_pending_releases.append([TAP_FRAMES, keycode])


## One typed character: the keycode a keyboard would report, plus its unicode.
func type_char(c: String) -> void:
	var keycode := KEY_SPACE if c == " " else OS.find_keycode_from_string(c.to_upper())
	tap(keycode, c.unicode_at(0))


## Moves the OS cursor to `to` (viewport coordinates) as one motion event.
func move_to(to: Vector2) -> void:
	move_by(to - mouse)


## One motion event carrying `relative` (viewport pixels).
func move_by(relative: Vector2) -> void:
	mouse += relative
	var xf := _root.get_final_transform()
	var ev := InputEventMouseMotion.new()
	ev.position = xf * mouse
	ev.global_position = ev.position
	ev.relative = xf.basis_xform(relative)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_down else 0
	Input.parse_input_event(ev)


func button(pressed: bool) -> void:
	mouse_down = pressed
	var xf := _root.get_final_transform()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = xf * mouse
	ev.global_position = ev.position
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)
