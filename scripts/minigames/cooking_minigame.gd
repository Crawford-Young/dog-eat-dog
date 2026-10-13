extends Minigame

## Dinner's four verbs, on screen — fully diegetic timing (issue #11 round 5,
## user ruling: "stirring a pot should not be rhythm"). Each verb shows its
## own fiction for the same underlying timing skill:
##   chop: a knife bobs over the carrots — press at contact.
##   transfer: the board rocks — press at the level angle.
##   stir: the pot's sheen shifts as you circle the mouse — let go glossy.
##   pour: the ladle fill rises as you hold — let go at the line.
## Chop and transfer are graded by a BeatTimer (a press-timing skill); pour is
## graded by a HoldMeter driven by held time. Stir (issue #11 round 6, user
## ruling: "stir should be the mouse stirring") drives that SAME HoldMeter
## through actual circular mouse motion (CircleTracker revolutions) instead
## of hold time — the sheen fiction is unchanged, only what advances it is.
## All recipe economics stay in CookingSession — this script only turns input
## into (verb, quality) pairs, prints the prompt, and shows the fiction.
## The pan is lost (issue #17) on its spoil_limit-th spoiled step, or when the
## time limit runs out; a spoil-limit MISS carries the session result, so the
## real score still pays the cooking energy.

const PROMPTS := {
	"chop": "chop — press when the knife falls",
	"transfer": "tip the board in — press when it's level",
	"stir": "stir — hold and circle the pan, let go when it shines",
	"pour": "pour — hold, let go at the line",
}
## How many presses chop/transfer want before they commit.
const PRESS_COUNTS := {"chop": 3, "transfer": 1}
## Stir and pour both release inside this band of the hold meter — same value
## for both, so "how full" reads the same way in both fictions.
const HOLD_BAND_CENTER := 0.75
## The pulse the active target throbs at — white at rest, this at the peak.
const PULSE_COLOR := Color(1.4, 1.4, 1.0)
## Zone flash on every press/release, ported from breakfast_minigame.gd — same
## duration and colours: a hit reads bright white-green, a miss reads dim red,
## both fading back to whatever the target's ambient state is.
const FLASH_DURATION := 0.3
const FLASH_HIT := Color(1.4, 1.8, 1.4)
const FLASH_MISS := Color(0.6, 0.3, 0.3)
## Pan's sheen at a fresh/dull stir, at its glossiest (band center), and once
## overworked past it.
const SHEEN_DULL := Color.WHITE
const SHEEN_GLOSSY := Color(1.25, 1.3, 1.4)
const SHEEN_OVERWORKED := Color(0.8, 0.7, 0.6)
## Where the knife travels — fractions of the scene's own height, so it stays
## resolution-independent without referencing a sibling's computed rect.
const KNIFE_RAISED_FRAC := 0.36
const KNIFE_CONTACT_FRAC := 0.44
## Same dead-zone shower.tscn's %Spot uses. The round-2 bug was a ~115px
## radius derived from the pan's own size — do not re-derive it that way.
const STIR_MIN_RADIUS := 12.0
## The meter fills to 1.0 over this many revolutions — the 0.75 band center
## lands at 2.25 revolutions, a stir and a quarter past two.
const STIR_FULL_REVOLUTIONS := 3.0
const FAIL_GAG := "🍳🔥"

var _session: CookingSession
var _text_speed: float = Typewriter.DEFAULT_CHARS_PER_SEC
var _window: float = 0.3
var _beat_speed: float = 1.2
## Spoiled steps that lose the pan. The default sits past the recipe, so a
## host that passes no limit never trips it.
var _spoil_limit: int = CookingSession.VERBS.size() + 1
var _beat: BeatTimer
var _meter: HoldMeter
var _presses: int = 0
var _hits: int = 0
var _holding: bool = false
var _tracker: CircleTracker
var _last_revs: float = 0.0
var _pulse_t: float = 0.0
var _flash_t: float = 0.0
var _flash_color: Color = Color.WHITE
var _flash_target: CanvasItem = null

@onready var _prompt: Label = %Prompt
@onready var _progress: ProgressBar = %Progress
@onready var _gesture_bar: ProgressBar = %GestureBar
@onready var _knife: ColorRect = %Knife
@onready var _pan: Control = %Pan
@onready var _pan_glow: ColorRect = %PanGlow
@onready var _pan_fill: ColorRect = %PanFill
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
	_spoil_limit = params.get("spoil_limit", _spoil_limit)
	_session = CookingSession.new(params.get("tolerance", 0.3))
	# The board rocks around its own center, not its top-left corner.
	_board.pivot_offset = _board.size / 2.0
	_announce()
	_start(params)


## Shows only the current verb's props — the knife and carrots for chop, the
## board (now carrying the chopped bits) for transfer, the stir spot for
## stir, the ladle for pour. The pan itself is never hidden; it's the one
## thing every verb happens over. The gesture bar always resets to empty.
func _announce() -> void:
	_progress.value = float(_session.index) / float(CookingSession.VERBS.size())
	_gesture_bar.value = 0.0
	if _session.is_done():
		_carrots.visible = false
		_knife.visible = false
		_board.visible = false
		_pan_glow.visible = false
		_stir_spot.visible = false
		_ladle.visible = false
		_beat = null
		_meter = null
		_finish_with(_session.result())
		return
	var verb := CookingSession.VERBS[_session.index]
	_carrots.visible = verb == "chop"
	_knife.visible = verb == "chop"
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
	_holding = false
	_tracker = null
	_last_revs = 0.0
	if verb == "chop" or verb == "transfer":
		_beat = BeatTimer.new(_beat_speed, _window)
		_meter = null
	elif verb == "stir":
		_beat = null
		# Speed is irrelevant here — stir never ticks. Mouse circling feeds
		# the meter through advance() instead (issue #11 round 6: "stir
		# should be the mouse stirring", not a hold timer).
		_meter = HoldMeter.new(0.0, HOLD_BAND_CENTER, _window)
	else:
		_beat = null
		# Half beat speed: a full fill takes ~1.7s at the default 1.2, leaving
		# the band reachable without a twitch-timed release. Width narrows
		# with energy deficit exactly like the beat window did — same
		# difficulty knob, reused rather than duplicated.
		_meter = HoldMeter.new(_beat_speed * 0.5, HOLD_BAND_CENTER, _window)
	_typer.play(PROMPTS[verb], _text_speed)


## The one place a verb reaches the session. Kept as its own method so the
## smoke test can walk the recipe without synthesising an input.
func _commit(verb: String, quality: float) -> void:
	_session.act(verb, quality)
	if _session.spoiled >= _spoil_limit:
		_fail(FAIL_GAG, _session.result())
		return
	_announce()


func _on_timeout() -> void:
	_fail(FAIL_GAG)


## Chop = fraction of its 3 presses that landed on the beat. Transfer is a
## single press, so its quality is just whether that one press hit.
func _quality_for(verb: String) -> float:
	if verb == "chop":
		return float(_hits) / 3.0
	return 1.0 if _hits >= 1 else 0.4


## Per-press feedback so the prop visibly changes on every input (issue #11
## round 2 lesson) — chop hides the carrot it just chopped, transfer hides
## the board it just tipped into the pan.
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


func _stamp_flash(verb: String, hit: bool) -> void:
	_flash_t = FLASH_DURATION
	_flash_color = FLASH_HIT if hit else FLASH_MISS
	_flash_target = _flash_target_for(verb)


func _flash_target_for(verb: String) -> CanvasItem:
	match verb:
		"chop":
			return _knife
		"transfer", "stir":
			return _pan_fill
		"pour":
			return _ladle_fill
	return null


## Chop/transfer: same shape as breakfast_minigame.gd's _press() — sample the
## beat, count the hit, commit once the verb's press count is reached.
func _press() -> void:
	var verb := CookingSession.VERBS[_session.index]
	var hit := _beat.press()
	if hit:
		_hits += 1
	_presses += 1
	_stamp_flash(verb, hit)
	_apply_press_feedback(verb)
	if _presses >= PRESS_COUNTS[verb]:
		_commit(verb, _quality_for(verb))


func _start_hold() -> void:
	_holding = true


## Stir's own press-start: mouse only (SPACE can't stir a pot), and a fresh
## CircleTracker centered on the pan — same shape shower.tscn uses for its
## scrub spots.
func _start_stir() -> void:
	_holding = true
	_tracker = CircleTracker.new(_pan.get_global_rect().get_center(), STIR_MIN_RADIUS)
	_last_revs = 0.0


## Mouse motion while stirring: feed the tracker, advance the meter by the
## revolutions gained since the last feed (not the running total — advance()
## accumulates, so re-feeding the whole total would double-count), and the
## stir spot follows the cursor — the spoon IS the mouse now.
func _feed_stir(pos: Vector2) -> void:
	_tracker.feed(pos)
	_meter.advance((_tracker.revolutions - _last_revs) / STIR_FULL_REVOLUTIONS)
	_last_revs = _tracker.revolutions
	_stir_spot.global_position = pos - _stir_spot.size / 2.0


## Stir/pour: the hold ends here. Guarded against a stray release that never
## had a matching press (nothing upstream guarantees one-press-then-release
## pairing for raw input events).
func _release_hold() -> void:
	if not _holding:
		return
	_holding = false
	var verb := CookingSession.VERBS[_session.index]
	var hit := _meter.release()
	_stamp_flash(verb, hit)
	_commit(verb, 1.0 if hit else 0.4)


## Copied from breakfast_minigame.gd `_unhandled_input` — a left-click anywhere or SPACE
## is a press, for chop/transfer/pour. Stir is mouse-only (issue #11 round 6:
## "stir should be the mouse stirring") — it does not accept SPACE at all.
func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var spaced: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE
	var released_click: bool = event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var released_space: bool = event is InputEventKey and not event.pressed \
			and event.physical_keycode == KEY_SPACE
	var verb := CookingSession.VERBS[_session.index]
	match verb:
		"chop", "transfer":
			if clicked or spaced:
				_press()
		"stir":
			if clicked:
				_start_stir()
			elif event is InputEventMouseMotion and _holding:
				_feed_stir(event.position)
			elif released_click:
				_release_hold()
		"pour":
			if clicked or spaced:
				_start_hold()
			elif released_click or released_space:
				_release_hold()


func _process(delta: float) -> void:
	if not _running:
		return
	var verb := CookingSession.VERBS[_session.index]
	_pulse_t += delta
	_update_pulse(verb)
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
	match verb:
		"chop":
			_beat.tick(delta)
			_update_knife()
		"transfer":
			_beat.tick(delta)
			_board.rotation_degrees = (_beat.position - 0.5) * 40.0
		"stir":
			# Motion-driven now — the meter only advances from mouse circling
			# (_feed_stir), never from ticking. Sheen still reads every frame.
			_update_pan_sheen()
		"pour":
			if _holding:
				_meter.tick(delta)
			_ladle_fill.anchor_top = 1.0 - _meter.value
	# Flash overlays whatever the ambient state (pulse/sheen) just set, on
	# top of it, for FLASH_DURATION — this is also what lets a flash stamped
	# on one verb keep decaying visibly into the NEXT verb's frames, since
	# %PanFill (transfer and stir's shared flash target) is never hidden by
	# the verb swap the way the old per-verb props were.
	if _flash_t > 0.0 and _flash_target != null:
		_flash_target.modulate = _flash_color.lerp(Color.WHITE, 1.0 - _flash_t / FLASH_DURATION)
	_update_gesture_bar(verb)


func _update_knife() -> void:
	var contact_y := size.y * KNIFE_CONTACT_FRAC
	var raised_y := size.y * KNIFE_RAISED_FRAC
	var frac := 1.0 - absf(_beat.position - 0.5) * 2.0
	_knife.position.y = raised_y + (contact_y - raised_y) * frac


## Dull white -> glossy at the band center -> overworked past it. Piecewise:
## the first half of the hold reads as it getting there, the second half as
## having gone too far.
func _update_pan_sheen() -> void:
	if _meter == null:
		return
	var v := _meter.value
	if v <= HOLD_BAND_CENTER:
		_pan_fill.modulate = SHEEN_DULL.lerp(SHEEN_GLOSSY, v / HOLD_BAND_CENTER)
	else:
		_pan_fill.modulate = SHEEN_GLOSSY.lerp(
			SHEEN_OVERWORKED, (v - HOLD_BAND_CENTER) / (1.0 - HOLD_BAND_CENTER)
		)


## Your-input-is-registering channel — the same job shower.tscn's ScrubBar
## does. Chop/transfer read press count; stir/pour read the hold meter.
func _update_gesture_bar(verb: String) -> void:
	if verb == "chop" or verb == "transfer":
		_gesture_bar.value = float(_presses) / float(PRESS_COUNTS[verb])
	else:
		_gesture_bar.value = _meter.value if _meter != null else 0.0


## Which prop the current verb wants worked on. Board's children (the chopped
## bits) pulse for free — Godot's modulate propagates down the tree, so
## tinting the board tints its cargo without a separate pass.
func _pulse_targets_for(verb: String) -> Array:
	match verb:
		"chop":
			var targets: Array = _carrots.get_children().filter(
				func(c: Node) -> bool: return (c as ColorRect).visible
			)
			targets.append(_knife)
			return targets
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
	_knife.modulate = Color.WHITE
	_board.modulate = Color.WHITE
	_stir_spot.modulate = Color.WHITE
	_ladle.modulate = Color.WHITE
	for target in _pulse_targets_for(verb):
		(target as CanvasItem).modulate = pulsing
