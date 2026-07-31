extends Minigame

## Dinner's four verbs, on screen. All recipe logic lives in CookingSession —
## this script only turns gestures into (verb, quality) pairs, prints the
## prompt, and points at what the verb wants: a per-gesture progress bar reads
## the input as it registers, the active target pulses, and a BeatTimer marker
## runs the whole time — landing the gesture inside the window is what makes
## it clean. Gestures stay; timing grades them. Skill is speed too, and speed
## is charged by the evening clock, so there is no separate timer here.

const PROMPTS := {
	"chop": "chop the carrots — click each one, on the beat",
	"transfer": "tip the board into the pan — drag it over, on the beat",
	"stir": "stir — circle the pan, on the beat",
	"pour": "pour — hold the ladle, release on the beat",
}
## A full stir is this many revolutions of the pan; CircleTracker counts them.
const STIR_REVOLUTIONS := 2.0
## Same dead-zone shower.tscn's %Spot uses. The pan is wide, and
## `_pan.size.x * 0.2` (the round-1 value) was a ~115px min radius — a stir
## tighter than a dinner-plate circle registered as nothing at all, the bug
## that made this verb read as dead.
const STIR_MIN_RADIUS := 12.0
## And a pour is this many seconds of unbroken hold.
const POUR_SECONDS := 1.2
## The pulse the active target throbs at — white at rest, this at the peak.
const PULSE_COLOR := Color(1.4, 1.4, 1.0)

var _session: CookingSession
var _text_speed: float = Typewriter.DEFAULT_CHARS_PER_SEC
var _window: float = 0.3
var _beat_speed: float = 1.2
var _beat: BeatTimer
var _chops: int = 0
var _hits: int = 0
var _tracker: CircleTracker
var _rev_whole: int = 0
var _rev_hits: int = 0
var _pour_held: float = 0.0
var _dragging: bool = false
var _pulse_t: float = 0.0

@onready var _prompt: Label = %Prompt
@onready var _progress: ProgressBar = %Progress
@onready var _gesture_bar: ProgressBar = %GestureBar
@onready var _rhythm_lane: ColorRect = %RhythmLane
@onready var _rhythm_zone: ColorRect = %RhythmZone
@onready var _rhythm_marker: ColorRect = %RhythmMarker
@onready var _pan: Control = %Pan
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
## always resets to empty — it reads THIS verb's input, which hasn't landed
## any yet.
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
	_chops = 0
	_hits = 0
	_rev_whole = 0
	_rev_hits = 0
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
## smoke test can walk the recipe without synthesising four gesture types.
func _commit(verb: String, quality: float) -> void:
	_session.act(verb, quality)
	_chops = 0
	_hits = 0
	_tracker = null
	_rev_whole = 0
	_rev_hits = 0
	_pour_held = 0.0
	_dragging = false
	_announce()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null or _session.is_done():
		return
	var verb := CookingSession.VERBS[_session.index]
	match verb:
		"chop":
			if event is InputEventMouseButton and event.pressed:
				for carrot in _carrots.get_children():
					var rect_carrot := carrot as ColorRect
					if rect_carrot.visible and rect_carrot.get_global_rect().has_point(event.position):
						# The click always chops the carrot it lands on — the
						# beat only grades how clean that chop was.
						rect_carrot.visible = false
						_chops += 1
						if _beat.press():
							_hits += 1
						break
				if _chops >= 3:
					_commit("chop", float(_hits) / 3.0)
		"transfer":
			if event is InputEventMouseButton:
				_dragging = event.pressed
			elif event is InputEventMouseMotion and _dragging:
				_board.global_position = event.position - _board.size / 2.0
				if _pan.get_global_rect().has_point(event.position):
					# Timing is the skill now — a drag landing the tip in the
					# pan on-beat is clean, off-beat spills a little.
					_commit("transfer", 1.0 if _beat.press() else 0.4)
		"stir":
			if event is InputEventMouseMotion:
				var center := _stir_spot.get_global_rect().get_center()
				if _tracker == null:
					_tracker = CircleTracker.new(center, STIR_MIN_RADIUS)
				_tracker.feed(event.position)
				# Sample the beat once per whole revolution crossed, not every
				# motion event — a revolution is the unit the recipe scores.
				var whole := floori(_tracker.revolutions)
				if whole > _rev_whole:
					_rev_whole = whole
					if _beat.press():
						_rev_hits += 1
				if _tracker.revolutions >= STIR_REVOLUTIONS:
					_commit("stir", float(_rev_hits) / STIR_REVOLUTIONS)
		"pour":
			if event is InputEventMouseButton:
				if not event.pressed and _pour_held > 0.0:
					# Commit happens on release, not at a full hold — a full
					# hold released off-beat still spills a little.
					var fill := minf(_pour_held, POUR_SECONDS) / POUR_SECONDS
					_commit("pour", fill * (1.0 if _beat.press() else 0.4))
				_pour_held = 0.0001 if event.pressed else 0.0


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
	if verb == "pour" and _pour_held > 0.0:
		# Capped, not auto-committed — pour ends on release now, so holding
		# past the full mark just waits at 1.0 fill for the beat to land.
		_pour_held = minf(_pour_held + delta, POUR_SECONDS)
	# The fill reads the hold on screen — empty when not held, full at cap.
	_ladle_fill.anchor_top = 1.0 - clampf(_pour_held / POUR_SECONDS, 0.0, 1.0)
	_update_gesture_bar(verb)


## Your-input-is-registering channel — the same job shower.tscn's ScrubBar
## does, one bar reused across all four verbs instead of one recognizer each.
## Untouched by the rhythm redo — this reads raw gesture progress, not timing.
func _update_gesture_bar(verb: String) -> void:
	match verb:
		"chop":
			_gesture_bar.value = float(_chops) / 3.0
		"transfer":
			_gesture_bar.value = 1.0 if _dragging else 0.0
		"stir":
			var revolutions := _tracker.revolutions if _tracker != null else 0.0
			_gesture_bar.value = clampf(revolutions / STIR_REVOLUTIONS, 0.0, 1.0)
		"pour":
			_gesture_bar.value = clampf(_pour_held / POUR_SECONDS, 0.0, 1.0)


## Which prop the current verb wants worked on. Board's children (the chopped
## bits) pulse for free — Godot's modulate propagates down the tree, so
## tinting the board tints its cargo without a separate pass. Untouched by the
## rhythm redo.
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
## Untouched by the rhythm redo.
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
