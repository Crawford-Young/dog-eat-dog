class_name DinnerSession
extends RefCounted

## Dinner as a walk (issue #18). The dog stands on a floor 0..1 wide, the pan at
## the left end and the phone at the right, and walks `speed` floor widths a
## second along its heading (-1 left, 0 standing, 1 right). Reaching the pan
## cooks; reaching the phone orders takeout. A dog that cannot pay for takeout
## stops at the phone and nothing happens. The first decision ends the walk;
## the time limit that ends an undecided one is the minigame's.

const COOK := "cook"
const TAKEOUT := "takeout"
const PAN := 0.0
const PHONE := 1.0
## The slowest the dog walks: a zero or negative speed reads as this.
const MIN_SPEED := 0.05

var _speed: float
var _can_afford: bool
var _position: float
var _heading := 0
var _outcome := ""


## `params` is Difficulty.dinner_params' shape: speed (floor widths a second)
## and start (a floor fraction), plus optional can_afford (true).
func _init(params: Dictionary) -> void:
	_speed = maxf(params.speed, MIN_SPEED)
	_position = clampf(params.start, PAN, PHONE)
	_can_afford = params.get("can_afford", true)


func speed() -> float:
	return _speed


func can_afford() -> bool:
	return _can_afford


## Where the dog stands along the floor.
func position() -> float:
	return _position


## -1 toward the pan, 1 toward the phone, 0 standing.
func heading() -> int:
	return _heading


## COOK or TAKEOUT once decided; "" while the dog is still on its way.
func outcome() -> String:
	return _outcome


## Seconds of walking from here to `target` (PAN or PHONE).
func seconds_to(target: float) -> float:
	return absf(target - _position) / _speed


## Sets the heading by sign. Ignored once dinner is decided.
func walk(heading: int) -> void:
	if _outcome == "":
		_heading = signi(heading)


## Walks the dog on. A step that reaches the pan cooks; one that reaches the
## phone orders, if the dog can pay. Standing still decides nothing, so a dog
## set down on a target still has to take a step.
func tick(delta: float) -> void:
	if _outcome != "" or _heading == 0:
		return
	_position += _heading * _speed * delta
	if _position <= PAN:
		_position = PAN
		_decide(COOK)
	elif _position >= PHONE:
		_position = PHONE
		if _can_afford:
			_decide(TAKEOUT)


func _decide(outcome: String) -> void:
	_outcome = outcome
	_heading = 0
