extends Minigame

## Three timing beats: catch the toast, flip the egg, stack the cakes. Click
## (or SPACE) when the marker crosses the plate zone. Hits = bigger energy
## refill downstream; misses burn it a little.
##
## Prop + feedback parity with cooking's rhythm redo: the active beat's food
## is drawn and pulses, and %HitZone flashes on every press — bright
## white-green for a hit, dim red for a miss.

const BEAT_NAMES := ["toast!", "egg!", "cakes!"]
## The pulse the active prop throbs at — white at rest, this at the peak.
## Same values as cooking's PULSE_COLOR, ported rather than reinvented.
const PULSE_COLOR := Color(1.4, 1.4, 1.0)
## How long a press's hit/miss flash lasts before fading back to plain white.
const FLASH_DURATION := 0.3
const FLASH_HIT := Color(1.4, 1.8, 1.4)
const FLASH_MISS := Color(0.6, 0.3, 0.3)

var _beat: BeatTimer
var _beats_total: int = 3
var _beats_done: int = 0
var _hits: int = 0
var _speed: float = 1.6
var _window: float = 0.3
var _running: bool = false
var _pulse_t: float = 0.0
var _flash_t: float = 0.0
var _flash_color: Color = Color.WHITE
var _active_prop: CanvasItem = null

@onready var _marker: ColorRect = %Marker
@onready var _zone: ColorRect = %HitZone
@onready var _lane: ColorRect = %Lane
@onready var _beat_label: Label = %BeatLabel
@onready var _toast: ColorRect = %Toast
@onready var _egg: ColorRect = %Egg
@onready var _cakes: Control = %Cakes


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
	var beat_name: String = BEAT_NAMES[_beats_done % BEAT_NAMES.size()]
	_beat_label.text = beat_name
	# Only the current beat's food is on screen — same "one thing says me" rule
	# cooking's props follow.
	_toast.visible = beat_name == "toast!"
	_egg.visible = beat_name == "egg!"
	_cakes.visible = beat_name == "cakes!"
	_active_prop = (
		_toast if beat_name == "toast!"
		else (_egg if beat_name == "egg!" else _cakes)
	)
	var zone_width := _lane.size.x * _window
	_zone.size.x = zone_width
	_zone.position.x = _lane.position.x + _lane.size.x * 0.5 - zone_width / 2.0


func _process(delta: float) -> void:
	if not _running:
		return
	_beat.tick(delta)
	_marker.position.x = _lane.position.x + _lane.size.x * _beat.position \
			- _marker.size.x / 2.0
	_pulse_t += delta
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
	_update_visuals()


## Pulse ported straight from cooking_minigame.gd's _update_pulse — the active
## prop is the sole pulse target. The flash lands on %HitZone, not the prop:
## _press() swaps the prop in the SAME synchronous call that stamps the flash
## (_start_beat() runs before the next frame), so a hidden outgoing prop would
## never render its flash — the zone is the one thing on screen both before
## and after the swap, so it is the only place the flash can actually read.
func _update_visuals() -> void:
	if _active_prop != null:
		var glow := 0.5 + 0.5 * sin(_pulse_t * 4.0)
		_active_prop.modulate = Color.WHITE.lerp(PULSE_COLOR, glow)
	if _flash_t > 0.0:
		_zone.modulate = _flash_color.lerp(Color.WHITE, 1.0 - _flash_t / FLASH_DURATION)
	else:
		_zone.modulate = Color.WHITE


func _press() -> void:
	var hit := _beat.press()
	if hit:
		_hits += 1
	_flash_t = FLASH_DURATION
	_flash_color = FLASH_HIT if hit else FLASH_MISS
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
