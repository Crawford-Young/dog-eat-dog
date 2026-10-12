class_name RngSource
extends RefCounted

## The one place a run's randomness comes from. A master stream hands each slot
## a fresh RandomNumberGenerator, so a seed plus slot order reproduces a whole
## run, and a slot that ignores its rng cannot shift the others.

var _master := RandomNumberGenerator.new()


## Unseeded by default (a real game); `seeded` pins the whole run.
func _init(seed_value: int = 0, is_seeded: bool = false) -> void:
	if is_seeded:
		_master.seed = seed_value
	else:
		_master.randomize()


static func seeded(seed_value: int) -> RngSource:
	return RngSource.new(seed_value, true)


## A fresh RNG seeded from the master stream. Call once per slot, always.
func next_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _master.randi()
	return rng


## What a minigame calls in setup(): the host's rng, or a fresh unseeded one
## when it is hosted without a game (the lab, unit tests).
static func from_params(params: Dictionary) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = params.get("rng")
	if rng != null:
		return rng
	rng = RandomNumberGenerator.new()
	rng.randomize()
	return rng
