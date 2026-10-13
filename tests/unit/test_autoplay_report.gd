extends GutTest

## The autoplay report's MISS count (issue #17): per slot, in both the
## markdown table and the JSON dump, so the loss rules can be tuned.

const Report := preload("res://scripts/dev/autoplay/report.gd")


func _tally() -> Dictionary:
	return {
		"profile": "sharp",
		"seed": 1,
		"days": 2,
		"seconds": {"wake": [1.0, 2.0], "brush": [1.5, 1.5], "drive": [30.0, 31.0]},
		"scores": {"wake": [1.0, 0.0], "brush": [1.0, 1.0], "drive": [1.0, 1.0]},
		"misses": {"wake": 1, "drive": 2},
		"overruns": [],
		"nights": 2,
		"late_band_nights": 0,
		"fumes_nights": 0,
		"sick_days": 0,
		"retired_day": 0,
		"freetime_games": 0,
		"skips": {},
		"final_day": 2,
		"final_rank": "intern",
		"final_savings": 10,
		"retirement_target": 4000,
		"frames": 600,
		"wall_seconds": 1.0,
	}


func _row(markdown: String, slot: String) -> String:
	for line in markdown.split("\n"):
		if line.begins_with("| %s |" % slot):
			return line
	return ""


func test_the_table_counts_each_slots_misses() -> void:
	var markdown := Report.markdown(_tally())
	assert_string_contains(markdown, "| misses |", "the table has a misses column")
	assert_true(_row(markdown, "wake").ends_with("| 1 |"), _row(markdown, "wake"))
	assert_true(_row(markdown, "drive").ends_with("| 2 |"), _row(markdown, "drive"))
	assert_true(_row(markdown, "brush").ends_with("| 0 |"), "a slot that never missed reads 0")


func test_the_json_carries_the_misses_per_slot() -> void:
	var parsed: Dictionary = JSON.parse_string(Report.json(_tally()))
	assert_eq(parsed.misses, {"wake": 1.0, "drive": 2.0})


func test_a_tally_without_misses_still_prints() -> void:
	var tally := _tally()
	tally.erase("misses")
	assert_true(_row(Report.markdown(tally), "wake").ends_with("| 0 |"))
