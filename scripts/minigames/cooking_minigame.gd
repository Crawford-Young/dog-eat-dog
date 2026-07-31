extends Minigame

## Dinner's four verbs, on screen. All recipe logic lives in CookingSession —
## this script only turns gestures into (verb, quality) pairs and prints the
## prompt. Skill is speed, and speed is charged by the evening clock, so there
## is no timer here.

const PROMPTS := {
	"chop": "chop the carrots — click each one",
	"transfer": "tip the board into the pan — drag it over",
	"stir": "stir — circle the pan",
	"pour": "pour — hold the ladle steady",
}
## A full stir is this many revolutions of the pan; CircleTracker counts them.
const STIR_REVOLUTIONS := 2.0
## And a pour is this many seconds of unbroken hold.
const POUR_SECONDS := 1.2

var _session: CookingSession
var _text_speed: float = Typewriter.DEFAULT_CHARS_PER_SEC
var _chops: int = 0
var _tracker: CircleTracker
var _pour_held: float = 0.0
var _dragging: bool = false

@onready var _prompt: Label = %Prompt
@onready var _progress: ProgressBar = %Progress
@onready var _pan: Control = %Pan
@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_prompt)


func setup(params: Dictionary) -> void:
	_text_speed = params.get("text_speed", _text_speed)
	_session = CookingSession.new(params.get("tolerance", 0.3))
	_announce()


func _announce() -> void:
	_progress.value = float(_session.index) / float(CookingSession.VERBS.size())
	if _session.is_done():
		_finish_with(_session.result())
		return
	_typer.play(PROMPTS[CookingSession.VERBS[_session.index]], _text_speed)


## The one place a verb reaches the session. Kept as its own method so the
## smoke test can walk the recipe without synthesising four gesture types.
func _commit(verb: String, quality: float) -> void:
	_session.act(verb, quality)
	_chops = 0
	_tracker = null
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
				_chops += 1
				if _chops >= 3:
					_commit("chop", 1.0)
		"transfer":
			if event is InputEventMouseButton:
				_dragging = event.pressed
			elif event is InputEventMouseMotion and _dragging:
				if _pan.get_global_rect().has_point(event.position):
					# Quality is how straight the tip was — a wandering drag
					# spills, and spilling is a spoiled step, not a failure.
					_commit("transfer", clampf(1.0 - event.velocity.length() / 4000.0, 0.0, 1.0))
		"stir":
			if event is InputEventMouseMotion:
				var center := _pan.get_global_rect().get_center()
				if _tracker == null:
					_tracker = CircleTracker.new(center, _pan.size.x * 0.2)
				_tracker.feed(event.position)
				if _tracker.revolutions >= STIR_REVOLUTIONS:
					_commit("stir", 1.0)
		"pour":
			if event is InputEventMouseButton:
				if not event.pressed and _pour_held > 0.0:
					# Let go early and the sauce goes everywhere.
					_commit("pour", clampf(_pour_held / POUR_SECONDS, 0.0, 1.0))
				_pour_held = 0.0001 if event.pressed else 0.0


func _process(delta: float) -> void:
	if _session == null or _session.is_done():
		return
	if CookingSession.VERBS[_session.index] == "pour" and _pour_held > 0.0:
		_pour_held += delta
		if _pour_held >= POUR_SECONDS:
			_commit("pour", 1.0)
