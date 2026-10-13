extends GutTest

## The HUD's read of a finished slot (issue #17, #11 "HUD layout"): HIT, MISS
## or a muted SKIP for the playable slots in the #11 loss table, nothing for
## the beats and cards that are not games.

const PLAYABLE: Array[String] = ["wake", "brush", "shower", "clothes", "breakfast",
		"drive", "work_am", "lunch", "work_pm", "cooking", "freetime"]
const EXEMPT: Array[String] = ["warning", "sleep", "retire_offer", "sick", "coffee",
		"dinner", "drive_home", "late_arrival", "rank_news"]


func test_the_counted_slots_are_the_loss_tables_playable_slots() -> void:
	assert_eq(Verdict.COUNTED_SLOTS, PLAYABLE)


func test_a_game_neither_failed_nor_skipped_is_a_hit() -> void:
	for slot in PLAYABLE:
		assert_eq(Verdict.of(slot, {"score": 0.4, "skipped": false, "failed": false}), Verdict.HIT, slot)
	assert_eq(Verdict.of("wake", {"score": 1.0, "skipped": false}), Verdict.HIT,
			"a result without a failed key is not a miss")


func test_a_failed_game_is_a_miss() -> void:
	for slot in PLAYABLE:
		assert_eq(Verdict.of(slot, {"score": 0.0, "skipped": false, "failed": true}), Verdict.MISS, slot)


func test_a_voluntary_skip_is_a_skip() -> void:
	for slot in ["brush", "shower", "breakfast"]:
		assert_eq(Verdict.of(slot, {"score": 0.0, "skipped": true}), Verdict.SKIP, slot)


func test_a_slot_that_is_not_a_game_has_no_verdict() -> void:
	for slot in EXEMPT:
		assert_eq(Verdict.of(slot, {"score": 1.0, "skipped": false}), "", slot)
		assert_eq(Verdict.of(slot, {"score": 0.0, "skipped": true, "failed": true}), "", slot)


func test_the_strip_marks_each_verdict_in_order() -> void:
	assert_eq(Verdict.strip([]), "", "no games yet, no marks")
	assert_eq(
		Verdict.strip([Verdict.HIT, Verdict.SKIP, Verdict.MISS, Verdict.HIT]),
		"✅ – ❌ ✅",
	)
