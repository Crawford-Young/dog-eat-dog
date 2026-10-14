class_name CoffeeSession
extends RefCounted

## The coffee cart's cup grab (issue #18). A cup slides left to right along a
## track 0..1 wide at `speed` track widths a second, entering after `lead`
## seconds. A press while the cup sits in the grab zone is a clean grab (buy);
## a press while it does not is a spill; a cup left alone passes (water). A dog
## that cannot afford the cup cannot grab it, so its presses do nothing and
## the cup always passes. The first decision ends the session.

const BUY := "buy"
const SKIP := "skip"
const SPILL := "spill"
## The slowest the cup moves: a zero or negative speed reads as this.
const MIN_SPEED := 0.05

var _speed: float
var _zone_center: float
var _zone_width: float
var _can_afford: bool
## The cup's centre along the track; below 0 it has not come on screen yet.
var _position: float
var _outcome := ""


## `params` is Difficulty.cup_params' shape: speed, zone_center and zone_width
## (track fractions) and lead (seconds), plus optional can_afford (true).
func _init(params: Dictionary) -> void:
	_speed = maxf(params.speed, MIN_SPEED)
	_zone_center = params.zone_center
	_zone_width = maxf(params.zone_width, 0.0)
	_can_afford = params.get("can_afford", true)
	_position = -_speed * maxf(params.lead, 0.0)


func speed() -> float:
	return _speed


func zone_center() -> float:
	return _zone_center


func zone_width() -> float:
	return _zone_width


func can_afford() -> bool:
	return _can_afford


## The cup's centre along the track.
func position() -> float:
	return _position


## BUY, SKIP or SPILL once decided; "" while the cup is still in play.
func outcome() -> String:
	return _outcome


## True while the cup is on the track: past the left edge, not yet passed.
func cup_on_screen() -> bool:
	return _position >= 0.0 and _outcome != SKIP


func in_zone() -> bool:
	return absf(_position - _zone_center) <= _zone_width / 2.0


## Seconds until the cup reaches the zone's centre; negative once past it.
func seconds_to_zone() -> float:
	return (_zone_center - _position) / _speed


## A press: the outcome it decided (BUY in the zone, SPILL out of it), or ""
## when it did nothing - already decided, or the dog cannot afford the cup.
func grab() -> String:
	if _outcome != "" or not _can_afford:
		return ""
	_outcome = BUY if in_zone() else SPILL
	return _outcome


## The probe detail (#18 step 12): the outcome, the press offset from the
## zone centre in track widths (null for a cup left to pass), the zone's
## half-width to read it against, and whether the dog could pay.
func probe_detail() -> Dictionary:
	var pressed := _outcome == BUY or _outcome == SPILL
	return {
		"outcome": _outcome,
		"offset": _position - _zone_center if pressed else null,
		"half_zone": _zone_width / 2.0,
		"can_afford": _can_afford,
	}


## Slides the cup on; a cup that reaches the far edge undecided has passed.
func tick(delta: float) -> void:
	if _outcome != "":
		return
	_position += _speed * delta
	if _position >= 1.0:
		_position = 1.0
		_outcome = SKIP
