class_name Verdict
extends RefCounted

## The HUD's read of a finished slot (issue #17): HIT, MISS or a muted SKIP,
## stamped mid-screen and marked on the day's strip. Only the playable slots
## of the #11 loss table get one; narration beats, sleep, the retire offer,
## sick, the coffee and dinner cards and the drive home are not games.

const COUNTED_SLOTS: Array[String] = ["wake", "brush", "shower", "clothes", "breakfast",
		"drive", "work_am", "lunch", "work_pm", "cooking", "freetime"]
const HIT := "HIT"
const MISS := "MISS"
const SKIP := "SKIP"
## Neither the default font nor Twemoji carries ✓ (U+2713) or ✗ (U+2717), and
## Twemoji's ✔/✖ are near-black on the dark clear colour, so the strip uses the
## coloured check and cross. The dash is in the default font.
const MARKS := {HIT: "✅", MISS: "❌", SKIP: "–"}


## "" for a slot that is not a game. A loss outranks a skip, though a failed
## game closes its skip button, so a result never carries both.
static func of(slot: String, result: Dictionary) -> String:
	if slot not in COUNTED_SLOTS:
		return ""
	if result.get("failed", false):
		return MISS
	if result.get("skipped", false):
		return SKIP
	return HIT


## The day's marks in play order, space-separated.
static func strip(verdicts: Array) -> String:
	return " ".join(verdicts.map(func(verdict: String) -> String: return MARKS[verdict]))
