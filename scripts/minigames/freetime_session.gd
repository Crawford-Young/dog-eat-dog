class_name FreetimeSession
extends RefCounted

## The "one more game" loop. Resting on the game button long enough auto-plays
## a game — no click required, that is the whole joke — and every game played
## pulls harder. The only way out is a deliberate logoff. Pure, fully tested.


var games_played: int = 0

var _base_pull: float
var _dwell_needed: float
var _pull_growth: float
var _pull_ceiling: float
var _dwell: float = 0.0
var _done: bool = false


func _init(
	base_pull: float, dwell_needed: float, pull_growth: float, pull_ceiling: float
) -> void:
	_base_pull = base_pull
	_dwell_needed = maxf(dwell_needed, 0.0001)
	_pull_growth = pull_growth
	_pull_ceiling = pull_ceiling


## Cursor is resting on the game button. Returns true on the frame a game
## auto-starts.
func hover(dt: float) -> bool:
	if _done:
		return false
	_dwell += dt
	if _dwell < _dwell_needed:
		return false
	_dwell = 0.0
	games_played += 1
	return true


## Cursor left the game button — the dwell timer starts over.
func leave() -> void:
	_dwell = 0.0


func dwell_ratio() -> float:
	return clampf(_dwell / _dwell_needed, 0.0, 1.0)


## Capped on purpose: logoff is the ONLY exit, so an unbounded pull would
## eventually outrun any achievable mouse speed and close the loop for good.
## The ceiling keeps the fight winnable-but-hard however long the night runs.
func pull_strength() -> float:
	return minf(_base_pull + _pull_growth * games_played, _pull_ceiling)


func logoff() -> void:
	_done = true


func is_done() -> bool:
	return _done


## Decays with every game played. Wave-1 nothing consumes it yet (see the D1
## note in stat_effects.gd) — it is the hook for the wave-2 rep sink.
func score() -> float:
	return 1.0 / (1.0 + games_played)


func result() -> Dictionary:
	return {
		"score": score(),
		"skipped": false,
		"choice": "logoff",
		"games_played": games_played,
	}
