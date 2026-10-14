class_name BurstSession
extends RefCounted

## Work AM's word burst (issue #18): single words, one at a time, each typed
## before its window runs out. A typed word serves the next at once; an expired
## one is a miss and serves the next too, so the stream never waits. A wrong
## key is dropped (it costs only the time it took). Score = words typed / words
## shown, where shown counts only resolved words — the word still on screen
## when the shift ends never had its full window.
##
## Every word gets the same window (the rank's, over play speed), and the
## clarity tier picks the word: the lower the tier, the longer the word, never
## shorter (asserted). So a tired dog clears fewer words at any typing speed,
## and coffee's tier boost always helps. Letters by tier: 4 clean 3-4, 3 clean
## 5, 2 and 1 garbled 6-7, 0 keysmash 8-9.

const WORDS := {
	4: [
		"memo", "sync", "ping", "file", "deck", "task",
		"send", "plan", "note", "call", "fax", "log",
	],
	3: [
		"email", "draft", "quota", "audit", "agent",
		"staff", "sales", "brief", "forms", "chart",
	],
}
## The garbled tiers' source words, all longer than any tier-3 word.
const LONG_WORDS := [
	"invoice", "roadmap", "meeting", "minutes", "payroll",
	"office", "vendor", "ledger", "target", "budget",
]
## Share of a long word's letters swapped for noise at each garbled tier.
const GARBLE := {2: 0.25, 1: 0.6}
const LETTERS := "abcdefghijklmnopqrstuvwxyz"
const SMASH_MIN := 8
const SMASH_MAX := 9
## The slowest the stream runs: a zero or negative speed reads as this.
const MIN_SPEED := 0.1
## A floor under every window, so a zero window cannot stall tick().
const MIN_WINDOW := 0.1

## The word on screen and how many of its letters are typed.
var word: String = ""
var typed_count: int = 0
var words_typed: int = 0
var words_missed: int = 0
## Wrong keys pressed, across the whole burst.
var errors: int = 0

var _tier: int
var _rng: RandomNumberGenerator
var _window: float
var _left: float = 0.0
## Each resolved word, oldest first, for the probe: {window, seconds}, with
## seconds null for an expired word. Observation only; play never reads it.
var _resolved: Array[Dictionary] = []


## Every word's window is `window` / `speed`.
func _init(tier: int, window: float, speed: float, rng: RandomNumberGenerator) -> void:
	_tier = tier
	_rng = rng
	_window = maxf(window / maxf(speed, MIN_SPEED), MIN_WINDOW)
	_next_word()


## A word's full window, in seconds.
func window() -> float:
	return _window


## Seconds left before the current word expires.
func time_left() -> float:
	return _left


## The current word's time left as a 1 -> 0 fraction.
func window_fraction() -> float:
	return clampf(_left / _window, 0.0, 1.0)


## The letters of the current word still to type; never empty.
func remaining() -> String:
	return word.substr(typed_count)


## Types one character. True when it was the next letter (case-insensitive);
## a completed word scores and serves the next.
func input_char(c: String) -> bool:
	if c.to_lower() != word[typed_count]:
		errors += 1
		return false
	typed_count += 1
	if typed_count >= word.length():
		words_typed += 1
		_resolve(_window - _left)
		_next_word()
	return true


## Runs the current word's window down by `delta`; every word the time covers
## expires as a miss, and the overshoot carries into the next word.
func tick(delta: float) -> void:
	var rest := delta
	while rest >= _left:
		rest -= _left
		words_missed += 1
		_resolve(null)
		_next_word()
	_left -= rest


func words_shown() -> int:
	return words_typed + words_missed


## Words typed / words shown; 0 with nothing shown yet.
func score() -> float:
	var shown := words_shown()
	return float(words_typed) / shown if shown > 0 else 0.0


## The probe detail (#18 step 12): every resolved word's window and the
## seconds it took to type (null if it expired), and the typo count. The word
## still on screen is left out, as score() leaves it out.
func probe_detail() -> Dictionary:
	return {"words": _resolved.duplicate(true), "typos": errors}


func _resolve(seconds: Variant) -> void:
	_resolved.append({"window": _window, "seconds": seconds})


func _next_word() -> void:
	word = word_for(_tier, _rng, word)
	typed_count = 0
	_left = _window


## A word at clarity `tier` that is never `avoid` (the word just shown): 4 a
## short clean word, 3 a longer one, 2 and 1 a long word with GARBLE of its
## letters swapped for noise, 0 the longest keysmash.
static func word_for(tier: int, rng: RandomNumberGenerator, avoid := "") -> String:
	if tier >= 4:
		return _pick(WORDS[4], rng, avoid)
	if tier == 3:
		return _pick(WORDS[3], rng, avoid)
	var out := ""
	if tier in GARBLE:
		for c in _pick(LONG_WORDS, rng, ""):
			out += _letter(rng) if rng.randf() < GARBLE[tier] else c
	else:
		for i in rng.randi_range(SMASH_MIN, SMASH_MAX):
			out += _letter(rng)
	return unlike(out, avoid)


## `generated` unless it equals `avoid`, else `generated` with its last letter
## moved one along the alphabet: same length, and no retry loop to spin.
static func unlike(generated: String, avoid: String) -> String:
	if generated != avoid or generated.is_empty():
		return generated
	var last := LETTERS.find(generated[-1])
	return generated.left(-1) + LETTERS[(last + 1) % LETTERS.length()]


static func _pick(words: Array, rng: RandomNumberGenerator, avoid: String) -> String:
	var pool := words.filter(func(w: String) -> bool: return w != avoid)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _letter(rng: RandomNumberGenerator) -> String:
	return LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
