extends Minigame

## Dinner's four verbs, on screen. All recipe logic lives in CookingSession —
## this script only turns presses into (verb, quality) pairs, prints the
## prompt, and points at what the verb wants: a per-gesture progress bar reads
## the input as it registers, the active target pulses, and a BeatTimer marker
## runs the whole time — landing the press inside the window is what makes it
## clean. Skill is speed too, and speed is charged by the evening clock, so
## there is no separate timer here.
##
## Issue #11 round 4, user ruling: "space should be the button. click should be
## everywhere. similar to breakfast." A press is a left-click ANYWHERE or
## SPACE — same contract breakfast_minigame.gd uses — graded by the running
## beat. The four separate gesture recognizers (click-the-carrot, drag-into-
## pan, circle-the-spot, hold-and-release) retire in favor of this one input.

const PROMPTS := {
	"chop": "chop the carrots — click or SPACE, three on the beat",
	"transfer": "tip the board in — one press, on the beat",
	"stir": "stir — two presses, on the beat",
	"pour": "pour — one press, on the beat",
}
## How many presses each verb wants before it commits.
const PRESS_COUNTS := {"chop": 3, "transfer": 1, "stir": 2, "pour": 1}
## The pulse the active target throbs at — white at rest, this at the peak.
const PULSE_COLOR := Color(1.4, 1.4, 1.0)
## Zone flash on every press, ported from breakfast_minigame.gd — same
## duration and colours, same reasoning: a hit reads bright white-green, a
## miss reads dim red, both fading back to white over FLASH_DURATION.
const FLASH_DURATION := 0.3
const FLASH_HIT := Color(1.4, 1.8, 1.4)
const FLASH_MISS := Color(0.6, 0.3, 0.3)

var _session: CookingSession
var _text_speed: float = Typewriter.DEFAULT_CHARS_PER_SEC
var _window: float = 0.3
var _beat_speed: float = 1.2
var _beat: BeatTimer
var _presses: int = 0
var _hits: int = 0
var _pulse_t: float = 0.0
var _flash_t: float = 0.0
var _flash_color: Color = Color.WHITE

@onready var _prompt: Label = %Prompt
@onready var _progress: ProgressBar = %Progress
@onready var _gesture_bar: ProgressBar = %GestureBar
@onready var _rhythm_lane: ColorRect = %RhythmLane
@onready var _rhythm_zone: ColorRect = %RhythmZone
@onready var _rhythm_marker: ColorRect = %RhythmMarker
@onready var _pan_glow: ColorRect = %PanGlow
@onready var _stir_spot: ColorRect = %StirSpot
@onready var _carrots: Control = %Carrots
@onready var _board: ColorRect = %Board
@onready var _ladle: ColorRect = %Ladle
@onready var _ladle_fill: ColorRect = %LadleFill
@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_prompt)


func setup(params: Dictionary) -> void:
	_text_speed = params.get("text_speed", _text_speed)
	_window = params.get("window", _window)
	_beat_speed = params.get("beat_speed", _beat_speed)
	_session = CookingSession.new(params.get("tolerance", 0.3))
	# %RhythmZone ships with independent left/right anchors (a stretched box) —
	# Godot warns on any direct .size/.position write to a Control whose
	# opposite anchors differ. Collapse to matched anchors once, preserving
	# the current pixel rect, so _start_beat()'s per-verb resize is a plain
	# offset write with no anchor conflict — same trick breakfast_minigame.gd
	# uses for %HitZone.
	var zone_pos_y := _rhythm_zone.position.y
	var zone_size_y := _rhythm_zone.size.y
	_rhythm_zone.anchor_right = _rhythm_zone.anchor_left
	_rhythm_zone.anchor_bottom = _rhythm_zone.anchor_top
	_rhythm_zone.position.y = zone_pos_y
	_rhythm_zone.size.y = zone_size_y
	_announce()


## Shows only the current verb's props — the carrots and the board they sit on
## for chop, the same board (now carrying the chopped bits) for transfer, the
## stir spot for stir, the ladle for pour. The pan itself is never hidden;
## it's the one thing every verb happens over. The rhythm lane/zone/marker are
## NOT verb-gated — the beat runs the whole time, every verb. The gesture bar
## always resets to empty — it reads THIS verb's presses, which haven't
## landed any yet.
func _announce() -> void:
	_progress.value = float(_session.index) / float(CookingSession.VERBS.size())
	_gesture_bar.value = 0.0
	if _session.is_done():
		_carrots.visible = false
		_board.visible = false
		_pan_glow.visible = false
		_stir_spot.visible = false
		_ladle.visible = false
		_beat = null
		_finish_with(_session.result())
		return
	var verb := CookingSession.VERBS[_session.index]
	_carrots.visible = verb == "chop"
	_board.visible = verb == "chop" or verb == "transfer"
	for bit in _board.get_children():
		(bit as ColorRect).visible = verb == "transfer"
	_pan_glow.visible = verb == "transfer"
	_stir_spot.visible = verb == "stir"
	_ladle.visible = verb == "pour"
	if verb == "chop":
		for carrot in _carrots.get_children():
			(carrot as ColorRect).visible = true
	_presses = 0
	_hits = 0
	_start_beat()
	_typer.play(PROMPTS[verb], _text_speed)


## One fresh beat per verb — same shape as breakfast_minigame.gd's
## _start_beat(): a new BeatTimer, and the zone re-sized/re-centered on the
## lane for this verb's window.
func _start_beat() -> void:
	_beat = BeatTimer.new(_beat_speed, _window)
	var zone_width := _rhythm_lane.size.x * _window
	_rhythm_zone.size.x = zone_width
	_rhythm_zone.position.x = _rhythm_lane.position.x + _rhythm_lane.size.x * 0.5 - zone_width / 2.0


## The one place a verb reaches the session. Kept as its own method so the
## smoke test can walk the recipe without synthesising a press.
func _commit(verb: String, quality: float) -> void:
	_session.act(verb, quality)
	_announce()


## Chop = hits/3, stir = hits/2 — the fraction of this verb's presses that
## landed on the beat. Transfer and pour take exactly one press, so their
## quality is just whether that press hit.
func _quality_for(verb: String) -> float:
	match verb:
		"chop":
			return float(_hits) / 3.0
		"stir":
			return float(_hits) / 2.0
		_:
			return 1.0 if _hits >= 1 else 0.4


## Per-press feedback so the prop visibly changes on every input, not just at
## the end of the verb (issue #11 round 2 lesson). Stir has nothing beyond the
## gesture bar and the pulse — there is no single prop state a press could
## flip partway through two presses.
func _apply_press_feedback(verb: String) -> void:
	match verb:
		"chop":
			for carrot in _carrots.get_children():
				var rect_carrot := carrot as ColorRect
				if rect_carrot.visible:
					rect_carrot.visible = false
					break
		"transfer":
			_board.visible = false
		"pour":
			_ladle_fill.anchor_top = 0.0


## Same contract as breakfast_minigame.gd's _press(): sample the beat, count
## the hit, apply this verb's per-press feedback, commit once the verb's
## press count is reached.
func _press() -> void:
	var verb := CookingSession.VERBS[_session.index]
	var hit := _beat.press()
	if hit:
		_hits += 1
	_presses += 1
	_flash_t = FLASH_DURATION
	_flash_color = FLASH_HIT if hit else FLASH_MISS
	_apply_press_feedback(verb)
	if _presses >= PRESS_COUNTS[verb]:
		_commit(verb, _quality_for(verb))


## Copied from breakfast_minigame.gd:120-128 — a left-click anywhere or SPACE
## is a press. No per-verb gesture types any more.
func _unhandled_input(event: InputEvent) -> void:
	if _session == null or _session.is_done():
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var spaced: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE
	if clicked or spaced:
		_press()


func _process(delta: float) -> void:
	if _session == null or _session.is_done():
		return
	var verb := CookingSession.VERBS[_session.index]
	_pulse_t += delta
	_update_pulse(verb)
	if _beat != null:
		_beat.tick(delta)
		_rhythm_marker.position.x = _rhythm_lane.position.x + _rhythm_lane.size.x * _beat.position \
				- _rhythm_marker.size.x / 2.0
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
	_update_zone_flash()
	_update_gesture_bar(verb)


## Same reasoning as breakfast_minigame.gd's flash: decays from _flash_color
## back to white over FLASH_DURATION.
func _update_zone_flash() -> void:
	if _flash_t > 0.0:
		_rhythm_zone.modulate = _flash_color.lerp(Color.WHITE, 1.0 - _flash_t / FLASH_DURATION)
	else:
		_rhythm_zone.modulate = Color.WHITE


## Your-input-is-registering channel — the same job shower.tscn's ScrubBar
## does. Now a plain press-count fraction, uniform across all four verbs.
func _update_gesture_bar(verb: String) -> void:
	_gesture_bar.value = float(_presses) / float(PRESS_COUNTS[verb])


## Which prop the current verb wants worked on. Board's children (the chopped
## bits) pulse for free — Godot's modulate propagates down the tree, so
## tinting the board tints its cargo without a separate pass.
func _pulse_targets_for(verb: String) -> Array:
	match verb:
		"chop":
			return _carrots.get_children().filter(func(c: Node) -> bool: return (c as ColorRect).visible)
		"transfer":
			return [_board]
		"stir":
			return [_stir_spot]
		"pour":
			return [_ladle]
	return []


## One helper, one target set per verb — everything else sits at plain
## modulate so there is never more than one thing on screen saying "me".
func _update_pulse(verb: String) -> void:
	var glow := 0.5 + 0.5 * sin(_pulse_t * 4.0)
	var pulsing := Color.WHITE.lerp(PULSE_COLOR, glow)
	for carrot in _carrots.get_children():
		(carrot as ColorRect).modulate = Color.WHITE
	_board.modulate = Color.WHITE
	_stir_spot.modulate = Color.WHITE
	_ladle.modulate = Color.WHITE
	for target in _pulse_targets_for(verb):
		(target as CanvasItem).modulate = pulsing
