class_name TriageSession
extends RefCounted

## Work PM's inbox triage (issue #18): emails land in an inbox at a ramped
## rate, oldest on top. Each shows a subject icon, 3 work (reply) and 3 junk
## (trash); the top one is sorted reply or trash, right or wrong, and the next
## moves up. The email on top has `window` seconds, from reaching the top, to
## be sorted; left past it, it expires, shown and not correct. The inbox holds
## `capacity` emails: one landing on a full inbox is buried, shown and not
## correct — the avalanche, so falling behind the arrival rate costs score.
## Score = correct sorts / emails shown, where shown counts only resolved
## emails — the ones still waiting when the shift ends never had their turn.
##
## The window counts from the top, not from landing, so a backlog can never
## leave every email on top already out of time (a slow sorter would then sort
## nothing at all — the bot measured exactly that).
##
## The clarity tier is the read delay: the email on top is out of focus for
## `read_delay` seconds every time a new one reaches it, and a sort before it
## reads is dropped. A blurrier dog reads every email later, so it clears fewer
## at any reaction speed and the energy and coffee levers cannot read
## inverted (asserted for a fast and a slow actor). The read delay is the dog's
## eyes, not the inbox, so play speed does not shorten it.

## Icons 0..WORK_ICONS-1 are work (reply); the rest are junk (trash).
const ICON_COUNT := 6
const WORK_ICONS := 3
## What a sort did: nothing to sort (empty or still blurred), right, wrong.
const IGNORED := 0
const CORRECT := 1
const WRONG := 2
## The slowest the inbox runs: a zero or negative speed reads as this.
const MIN_SPEED := 0.1
## Floors under the window and the gap, so a zero cannot stall tick().
const MIN_WINDOW := 0.1
const MIN_GAP := 0.05
const DEFAULT_CAPACITY := 6

var correct: int = 0
var wrong: int = 0
var expired: int = 0
var buried: int = 0

var _window: float
var _gap: float
var _jitter: float
var _read_delay: float
var _capacity: int
var _rng: RandomNumberGenerator
## Oldest first: {id, icon}.
var _inbox: Array[Dictionary] = []
var _next_id: int = 0
var _until_arrival: float = 0.0
## Seconds before the email on top expires.
var _top_left: float = 0.0
## Seconds before the email on top reads; 0 once it does.
var _focus_left: float = 0.0
## Each resolved email, oldest first, for the probe: {correct, seconds}, with
## seconds null for one that expired or was buried. Observation only.
var _resolved: Array[Dictionary] = []


## `params` is Difficulty.triage_params' shape: window, gap and read_delay
## (seconds), plus optional speed (1), jitter (0) and capacity. The window and
## the gap are divided by speed; each gap is rolled within jitter (a 0..1
## share) either side of its mean. The first email is in the inbox from the
## start.
func _init(params: Dictionary, rng: RandomNumberGenerator) -> void:
	var speed := maxf(params.get("speed", 1.0), MIN_SPEED)
	_window = maxf(params.window / speed, MIN_WINDOW)
	_gap = maxf(params.gap / speed, MIN_GAP)
	_jitter = clampf(params.get("jitter", 0.0), 0.0, 1.0)
	_read_delay = maxf(params.read_delay, 0.0)
	_capacity = maxi(params.get("capacity", DEFAULT_CAPACITY), 1)
	_rng = rng
	_arrive()


## True for a work icon (sorted reply), false for junk (trash).
static func is_work(icon: int) -> bool:
	return icon < WORK_ICONS


## The top email's window, in seconds.
func window() -> float:
	return _window


## The mean seconds between arrivals.
func gap() -> float:
	return _gap


## The most emails the inbox holds, the top one included.
func capacity() -> int:
	return _capacity


func inbox_size() -> int:
	return _inbox.size()


## The waiting emails' icons, top first.
func icons() -> Array[int]:
	var out: Array[int] = []
	for email in _inbox:
		out.append(email.icon)
	return out


## The top email's id (ids count up from 0 as emails land); -1 when empty.
func front_id() -> int:
	return _inbox[0].id if not _inbox.is_empty() else -1


## The top email's icon; -1 when empty.
func front_icon() -> int:
	return _inbox[0].icon if not _inbox.is_empty() else -1


## Seconds before the top email expires; 0 when empty.
func front_time_left() -> float:
	return _top_left if not _inbox.is_empty() else 0.0


## The top email's time left as a 1 -> 0 fraction; 0 when empty.
func front_fraction() -> float:
	return clampf(front_time_left() / _window, 0.0, 1.0)


## True once the top email has come into focus; false with nothing on top.
func is_legible() -> bool:
	return not _inbox.is_empty() and _focus_left <= 0.0


## The top email's focus as a 0 -> 1 fraction (1 with no read delay).
func focus_fraction() -> float:
	if _read_delay <= 0.0:
		return 1.0
	return clampf(1.0 - _focus_left / _read_delay, 0.0, 1.0)


## Files the top email as reply (`reply` true) or trash once it reads, and
## says how that went; IGNORED with nothing legible on top.
func sort(reply: bool) -> int:
	if not is_legible():
		return IGNORED
	var right := is_work(_inbox[0].icon) == reply
	if right:
		correct += 1
	else:
		wrong += 1
	_resolve(right, _window - _top_left)
	_pop_top()
	return CORRECT if right else WRONG


## Runs the inbox forward by `delta`, landing and expiring every email the
## time covers in order (an expiry before an arrival at the same instant).
func tick(delta: float) -> void:
	var rest := delta
	while true:
		var expiry := not _inbox.is_empty() and _top_left <= _until_arrival
		var step := _top_left if expiry else _until_arrival
		if rest < step:
			break
		_advance(step)
		rest -= step
		if expiry:
			expired += 1
			_resolve(false, null)
			_pop_top()
		else:
			_arrive()
	_advance(rest)


func emails_shown() -> int:
	return correct + wrong + expired + buried


## Correct sorts / emails shown; 0 with nothing shown yet.
func score() -> float:
	var shown := emails_shown()
	return float(correct) / shown if shown > 0 else 0.0


## The probe detail (#18 step 12): every resolved email, sorted right or not,
## and the seconds from reaching the top to sorted (null if it expired or was
## buried). The emails still waiting are left out, as score() leaves them out.
func probe_detail() -> Dictionary:
	return {"emails": _resolved.duplicate(true)}


func _resolve(right: bool, seconds: Variant) -> void:
	_resolved.append({"correct": right, "seconds": seconds})


func _advance(seconds: float) -> void:
	_until_arrival -= seconds
	_top_left -= seconds
	_focus_left = maxf(_focus_left - seconds, 0.0)


## Lands the next email — on top of a full inbox it is buried — and rolls the
## gap to the one after.
func _arrive() -> void:
	var icon := _rng.randi_range(0, ICON_COUNT - 1)
	if _inbox.size() >= _capacity:
		buried += 1
		_resolve(false, null)
	else:
		_inbox.append({"id": _next_id, "icon": icon})
		if _inbox.size() == 1:
			_new_top()
	_next_id += 1
	_until_arrival = maxf(_gap * _rng.randf_range(1.0 - _jitter, 1.0 + _jitter), MIN_GAP)


func _pop_top() -> void:
	_inbox.pop_front()
	_new_top()


## The email now on top (if any) starts its whole window, out of focus.
func _new_top() -> void:
	_top_left = _window
	_focus_left = _read_delay
