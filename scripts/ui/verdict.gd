class_name Verdict
extends RefCounted

## The HUD's read of a finished slot (issue #17): HIT, MISS or a muted SKIP,
## stamped mid-screen and marked on the day's strip. Only the playable slots
## of the #11 loss table, plus the drive home since its home_by line (#18), the
## coffee cup grab and the dinner walk, get one; narration beats, sleep, the
## retire offer and sick are not games. Letting the cup pass (water) is a
## choice, not a result, so it gets none either.

const COUNTED_SLOTS: Array[String] = ["wake", "brush", "shower", "clothes", "breakfast",
		"drive", "coffee", "work_am", "lunch", "work_pm", "drive_home", "dinner", "cooking",
		"freetime"]
## The choice that makes a counted slot a non-game: the coffee cup left to pass.
const WATER := "skip"
const HIT := "HIT"
const MISS := "MISS"
const SKIP := "SKIP"
## Neither the default font nor Twemoji carries ✓ (U+2713) or ✗ (U+2717), and
## Twemoji's ✔/✖ are near-black on the dark clear colour, so the strip uses the
## coloured check and cross. The dash is in the default font.
const MARKS := {HIT: "✅", MISS: "❌", SKIP: "–"}


## "" for a slot that is not a game. A loss outranks a skip, though a failed
## game goes dead to input (`_running` gates its SkipButton), so a result
## never carries both.
static func of(slot: String, result: Dictionary) -> String:
	if slot not in COUNTED_SLOTS or (slot == "coffee" and result.get("choice") == WATER):
		return ""
	if result.get("failed", false):
		return MISS
	if result.get("skipped", false):
		return SKIP
	return HIT


## The day's marks in play order, space-separated.
static func strip(verdicts: Array) -> String:
	return " ".join(verdicts.map(func(verdict: String) -> String: return MARKS[verdict]))
