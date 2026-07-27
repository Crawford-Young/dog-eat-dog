extends Minigame

## Three timing beats: catch the toast, flip the egg, stack the cakes. Click
## (or SPACE) when the marker crosses the plate zone. Hits = bigger energy
## refill downstream; misses burn it a little.

const BEAT_NAMES := ["toast!", "egg!", "cakes!"]

var _beat: BeatTimer
var _beats_total: int = 3
var _beats_done: int = 0
var _hits: int = 0
var _speed: float = 1.6
var _window: float = 0.3
var _running: bool = false

@onready var _marker: ColorRect = %Marker
@onready var _zone: ColorRect = %HitZone
@onready var _lane: ColorRect = %Lane
@onready var _beat_label: Label = %BeatLabel


func setup(params: Dictionary) -> void:
	_speed = params.speed
	_window = params.window
	_beats_total = params.beats
	# HitZone ships with independent left/right and top/bottom anchors (a
	# stretched box) — Godot warns on any direct .size write to a Control
	# whose opposite anchors differ. Collapse to matched anchors once,
	# preserving the current pixel rect, so _start_beat()'s per-beat resize
	# is a plain offset write with no anchor conflict.
	var zone_pos_y := _zone.position.y
	var zone_size_y := _zone.size.y
	_zone.anchor_right = _zone.anchor_left
	_zone.anchor_bottom = _zone.anchor_top
	_zone.position.y = zone_pos_y
	_zone.size.y = zone_size_y
	_start_beat()
	_running = true


func _start_beat() -> void:
	_beat = BeatTimer.new(_speed, _window)
	_beat_label.text = BEAT_NAMES[_beats_done % BEAT_NAMES.size()]
	var zone_width := _lane.size.x * _window
	_zone.size.x = zone_width
	_zone.position.x = _lane.position.x + _lane.size.x * 0.5 - zone_width / 2.0


func _process(delta: float) -> void:
	if not _running:
		return
	_beat.tick(delta)
	_marker.position.x = _lane.position.x + _lane.size.x * _beat.position \
			- _marker.size.x / 2.0


func _press() -> void:
	if _beat.press():
		_hits += 1
	_beats_done += 1
	if _beats_done >= _beats_total:
		_running = false
		_finish(float(_hits) / _beats_total)
	else:
		_start_beat()


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var spaced: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE
	if clicked or spaced:
		_press()


func _on_skip_pressed() -> void:
	if _running:
		_running = false
		_finish(0.0, true)
