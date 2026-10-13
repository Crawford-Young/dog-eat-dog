class_name CookingSession
extends RefCounted

## Dinner's recipe, as pure logic. Four verbs in a fixed order; a wrong verb or
## a sloppy gesture spoils a step. Nothing here fails a dinner: a spoiled step
## is a smaller payoff, and since energy scales with the score, a bad cook eats
## badly. The pan minigame owns the loss rule (its spoil limit and time limit,
## issue #17) and still reports this session's score when it loses.
##
## Speed is charged by the evening clock rather than scored here: the longer
## the pan takes, the later the bedtime. That is why this class has no timer.

const VERBS: PackedStringArray = ["chop", "transfer", "stir", "pour"]

## How far through the recipe the pan is.
var index: int = 0
## Steps done wrong — either out of order, or inside tolerance but sloppy.
var spoiled: int = 0

var _tolerance: float


## `tolerance` is how far from a clean gesture still counts, 0..1. It widens
## with the dog's energy deficit — a wrecked dog gets more slack, not fewer
## steps, which keeps the recipe's shape constant across every energy tier.
func _init(tolerance: float) -> void:
	_tolerance = clampf(tolerance, 0.0, 1.0)


## Returns true when the verb was the one the recipe wanted, which is the
## caller's cue to move the prompt on.
func act(verb: String, quality: float) -> bool:
	if is_done():
		return false
	if verb != VERBS[index]:
		spoiled += 1
		return false
	if quality < 1.0 - _tolerance:
		spoiled += 1
	index += 1
	return true


func is_done() -> bool:
	return index >= VERBS.size()


func score() -> float:
	return clampf(1.0 - float(spoiled) / float(VERBS.size()), 0.0, 1.0)


func result() -> Dictionary:
	return {"score": score(), "skipped": false, "spoiled": spoiled}
